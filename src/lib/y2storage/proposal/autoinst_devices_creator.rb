#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "y2storage/proposal/partitions_distribution_calculator"
require "y2storage/proposal/partition_creator"
require "y2storage/proposal/md_creator"
require "y2storage/proposal/autoinst_creator_result"
require "y2storage/exceptions"

module Y2Storage
  module Proposal
    # Class to create and reuse devices during the AutoYaST proposal, based
    # on the information contained in the profile.
    #
    # ## Comparison with the guided proposal
    #
    # This class receives a devicegraph in which the previous devices have
    # already been deleted or resized according to the AutoYaST profile. This
    # is different from the guided setup equivalent step, in which the minimal
    # amount of existing devices are deleted/resized on demand while trying to
    # allocate the planned devices.
    #
    # ## Reducing planned devices when there is not enough space
    #
    # Another key difference with the guided proposal is that, when there is
    # not enough space (for partitions or logical volumes), it will do a second
    # attempt reducing all planned devices proportionally. In order to do so,
    # it will remove the min_size limit (setting it to just 1 byte) and,
    # additionally, it will set a proportional weight for every partition (see
    # {#flexible_devices}).
    #
    # Although this approach may not produce the optimal results, it is less
    # intrusive and easier to maintain than other alternatives. Bear in mind
    # that AutoYaST does not expect complex scenarios (like multiple disks with
    # several gaps), so the result should be good enough.
    #
    # If we were aiming for the optimal devices distribution, we should look at
    # {Y2Storage::Planned::PartitionsDistribution#assigned_space} and follow
    # the same approach (reducing min_size and setting a proportional weight)
    # when it is not possible to place the devices in the given free space. But
    # we would also need to do further changes, like skipping some checks when
    # running in this flexible mode.
    class AutoinstDevicesCreator
      include Yast::Logger

      # Constructor
      #
      # @param original_graph [Devicegraph] Devicegraph to be used as starting point
      def initialize(original_graph)
        @original_graph = original_graph
      end

      # Devicegraph including all the specified planned devices
      #
      # @param planned_devices [Planned::DevicesCollection] Devices to create/reuse
      # @param disk_names [Array<String>] Disks to consider
      #
      # @return [AutoinstCreatorResult] Result with new devicegraph in which all the
      #   planned devices have been allocated
      def populated_devicegraph(planned_devices, disk_names)
        # Process planned partitions
        log.info "planned devices = #{planned_devices.to_a.inspect}"
        log.info "disk names = #{disk_names.inspect}"

        # Process planned partitions
        parts_to_create, parts_to_reuse, creator_result =
          process_partitions(planned_devices, disk_names, original_graph.duplicate)

        # Process planned disk like devices (Xen virtual partitions and full disks)
        planned_disk_like_devs = process_disk_like_devs(planned_devices, creator_result.devicegraph)

        # Add planned disk like devices to reuse list so they can be considered for lvm and raids
        # later on.
        devs_to_reuse = parts_to_reuse + planned_disk_like_devs

        # Process planned Mds
        mds_to_create, mds_to_reuse, creator_result =
          process_mds(planned_devices, devs_to_reuse, creator_result)
        devs_to_reuse.concat(mds_to_reuse.flat_map(&:partitions))

        # Process planned Bcaches
        bcaches_to_create, bcaches_to_reuse, creator_result =
          process_bcaches(planned_devices, devs_to_reuse, creator_result)
        devs_to_reuse.concat(bcaches_to_reuse.flat_map(&:partitions))

        # Process planned Vgs
        planned_vgs, creator_result =
          process_vgs(planned_devices, devs_to_reuse, creator_result)

        Y2Storage::Proposal::AutoinstCreatorResult.new(
          creator_result, parts_to_create + mds_to_create + planned_vgs + bcaches_to_create
        )
      end

    protected

      # @return [Devicegraph] Original devicegraph
      attr_reader :original_graph

      # Finds the best distribution for the given planned partitions
      #
      # @param devicegraph        [Devicegraph] Devicegraph to calculate the distribution
      # @param planned_partitions [Array<Planned::Partition>] Partitions to add
      # @param disk_names         [Array<String>]             Names of disks to consider
      #
      # @see Proposal::PartitionsDistributionCalculator#best_distribution
      def best_distribution(devicegraph, planned_partitions, disk_names)
        disks = devicegraph.disk_devices.select { |d| disk_names.include?(d.name) }
        spaces = disks.map(&:free_spaces).flatten

        calculator = Proposal::PartitionsDistributionCalculator.new
        dist = calculator.best_distribution(planned_partitions, spaces)
        return dist if dist

        # Second try with more flexible planned partitions
        calculator.best_distribution(flexible_devices(planned_partitions), spaces)
      end

    private

      # Process planned partitions
      #
      # The devicegraph object is modified.
      #
      # @param planned_devices [Array<Planned::Device>] Devices to create/reuse
      # @param disk_names [Array<String>] Disks to consider
      # @param devicegraph [Devicegraph] Devicegraph to work on
      #
      # @return [Array<Array<Planned::Partition>, Array<Planned::Partition>, CreatorResult>]
      def process_partitions(planned_devices, disk_names, devicegraph)
        planned_partitions = sized_partitions(planned_devices.disk_partitions)
        parts_to_reuse, parts_to_create = planned_partitions.partition(&:reuse?)
        reuse_partitions(parts_to_reuse, devicegraph)
        creator_result = create_partitions(devicegraph, parts_to_create, disk_names)

        [parts_to_create, parts_to_reuse, creator_result]
      end

      # Process planned Mds
      #
      # @param planned_devices [Array<Planned::Device>] Devices to create/reuse
      # @param devs_to_reuse [Array<Planned::Device>] Devices to reuse
      # @param creator_result [CreatorResult] Partial result
      #
      # @return [Array<Array<Planned::Md>, Array<Planned::Md>, CreatorResult>]
      def process_mds(planned_devices, devs_to_reuse, creator_result)
        mds_to_reuse, mds_to_create = planned_devices.mds.partition(&:reuse?)
        devs_to_reuse_in_md = reusable_by_md(devs_to_reuse)
        reuse_mds(mds_to_reuse, creator_result)
        creator_result.merge!(create_mds(planned_devices.mds, creator_result, devs_to_reuse_in_md))

        [mds_to_create, mds_to_reuse, creator_result]
      end

      # Process planned Bcaches
      #
      # @param planned_devices [Array<Planned::Device>] Devices to create/reuse
      # @param devs_to_reuse [Array<Planned::Device>] Devices to reuse
      # @param creator_result [CreatorResult] Partial result
      # @return [Array<Array<Planned::Bcache>, Array<Planned::Bcache>, CreatorResult>]
      def process_bcaches(planned_devices, devs_to_reuse, creator_result)
        bcaches_to_reuse, bcaches_to_create = planned_devices.bcaches.partition(&:reuse?)
        reuse_bcaches(bcaches_to_reuse, creator_result)
        creator_result.merge!(
          create_bcaches(planned_devices.bcaches, creator_result, devs_to_reuse)
        )

        [bcaches_to_create, bcaches_to_reuse, creator_result]
      end

      # Process planned Vgs
      #
      # @param planned_devices [Array<Planned::Device>] Devices to create/reuse
      # @param devs_to_reuse [Array<Planned::Device>] Devices to reuse
      # @param creator_result [CreatorResult] Partial result
      #
      # @return [Array<Array<Planned::Md>, Array<Planned::Md>, CreatorResult>]
      def process_vgs(planned_devices, devs_to_reuse, creator_result)
        planned_vgs = planned_devices.vgs
        vgs_to_reuse = planned_vgs.select(&:reuse?)
        creator_result = reuse_vgs(vgs_to_reuse, creator_result)
        creator_result.merge!(set_up_lvm(planned_vgs, creator_result, devs_to_reuse))

        [planned_vgs, creator_result]
      end

      # Formats and/or mounts the disk like block devices (Xen virtual partitions and full disks)
      #
      # @param planned_devices [Array<Planned::Device>] all planned devices
      # @param devicegraph     [Devicegraph] devicegraph containing the Xen
      #   partitions or full disks. It will be modified.
      # @return                [Array<Planned::StrayBlkDevice,Planned::Disk>] all disk like
      #   block devices
      def process_disk_like_devs(planned_devices, devicegraph)
        planned_devs = planned_devices.select do |dev|
          dev.is_a?(Planned::StrayBlkDevice) || dev.is_a?(Planned::Disk)
        end
        planned_devs.each { |d| d.reuse!(devicegraph) }

        planned_devs
      end

      # Creates planned partitions in the given devicegraph
      #
      # @param new_partitions [Array<Planned::Partition>] Devices to create
      # @param disk_names     [Array<String>]             Disks to consider
      # @return [PartitionCreatorResult]
      def create_partitions(devicegraph, new_partitions, disk_names)
        log.info "Partitions to create: #{new_partitions}"
        primary, non_primary = new_partitions.partition(&:primary)
        parts_to_create = primary + non_primary

        dist = best_distribution(devicegraph, parts_to_create, disk_names)
        raise NoDiskSpaceError, "Could not find a valid partitioning distribution" if dist.nil?
        part_creator = Proposal::PartitionCreator.new(devicegraph)
        part_creator.create_partitions(dist)
      end

      # Creates volume groups in the given devicegraph
      #
      # @param vgs             [Array<Planned::LvmVg>]     List of planned volume groups to add
      # @param previous_result [Proposal::CreatorResult]   Starting point
      # @param devs_to_reuse   [Array<Planned::Partition, Planned::StrayBlkDevice>] List of devices
      #   to reuse as Physical Volumes
      # @return                [Proposal::CreatorResult] Result containing the specified volume groups
      def set_up_lvm(vgs, previous_result, devs_to_reuse)
        # log separately to be more readable
        log.info "BEGIN: set_up_lvm: vgs=#{vgs.inspect}"
        log.info "BEGIN: set_up_lvm: previous_result=#{previous_result.inspect}"
        log.info "BEGIN: set_up_lvm: devs_to_reuse=#{devs_to_reuse.inspect}"
        vgs.reduce(previous_result) do |result, vg|
          pvs = previous_result.created_names { |d| d.pv_for?(vg.volume_group_name) }
          pvs += devs_to_reuse.select { |d| d.pv_for?(vg.volume_group_name) }.map(&:reuse_name)
          result.merge(create_logical_volumes(result.devicegraph, vg, pvs))
        end
      end

      # Create volume group in the given devicegraph
      #
      # @param devicegraph [Devicegraph]                    Starting devicegraph
      # @param vg          [Planned::LvmVg]                 Volume group
      # @param pvs         [Planned::Partition,Planned::Md] List of physical volumes
      # @return            [Proposal::CreatorResult] Result containing the specified volume group
      def create_logical_volumes(devicegraph, vg, pvs)
        lvm_creator = Proposal::LvmCreator.new(devicegraph)
        lvm_creator.create_volumes(vg, pvs)
      rescue RuntimeError
        lvm_creator = Proposal::LvmCreator.new(devicegraph)
        new_vg = vg.clone
        new_vg.lvs = flexible_devices(vg.lvs)
        lvm_creator.create_volumes(new_vg, pvs)
      end

      # Reuses partitions for the given devicegraph
      #
      # Shrinking partitions/logical volumes should be processed first in order to free
      # some space for growing ones.
      #
      # @param reused_devices  [Array<Planned::Partition>] Partitions to reuse
      # @param devicegraph     [Devicegraph] Devicegraph to reuse partitions
      def reuse_partitions(reused_devices, devicegraph)
        shrinking, not_shrinking = reused_devices.partition { |d| d.shrink?(devicegraph) }
        (shrinking + not_shrinking).each { |d| d.reuse!(devicegraph) }
      end

      # Reuses volume groups for the given devicegraph
      #
      # @param reused_vgs  [Array<Planned::LvmVg>] Volume groups to reuse
      # @param previous_result [Proposal::CreatorResult] Result containing the devicegraph
      #   to work on
      def reuse_vgs(reused_vgs, previous_result)
        reused_vgs.each_with_object(previous_result) do |vg, result|
          lvm_creator = Proposal::LvmCreator.new(result.devicegraph)
          result.merge!(lvm_creator.reuse_volumes(vg))
        end
      end

      # Reuses MD RAIDs for the given devicegraph
      #
      # @param reused_mds      [Array<Planned::Md>] MD RAIDs to reuse
      # @param previous_result [Proposal::CreatorResult] Starting point
      #   to work on
      # @return [Proposal::CreatorResult] Result containing the reused MD RAID devices
      def reuse_mds(reused_mds, previous_result)
        reused_mds.each_with_object(previous_result) do |md, result|
          md_creator = Proposal::MdCreator.new(result.devicegraph)
          result.merge!(md_creator.reuse_partitions(md))
        end
      end

      # Reuses Bcaches for the given devicegraph
      #
      # @param reused_bcaches  [Array<Planned::Bcache>] Bcaches to reuse
      # @param previous_result [Proposal::CreatorResult] Starting point
      #   to work on
      # @return [Proposal::CreatorResult] Result containing the reused Bcache devices
      def reuse_bcaches(reused_bcaches, previous_result)
        reused_bcaches.each_with_object(previous_result) do |bcache, result|
          bcache_creator = Proposal::BcacheCreator.new(result.devicegraph)
          result.merge!(bcache_creator.reuse_partitions(bcache))
        end
      end

      # Creates MD RAID devices in the given devicegraph
      #
      # @param mds             [Array<Planned::Md>]        List of planned MD arrays to create
      # @param previous_result [Proposal::CreatorResult]   Starting point
      # @param devs_to_reuse   [Array<Planned::Partition, Planned::StrayBlkDevice>] List of devices
      #   to reuse
      # @return                [Proposal::CreatorResult] Result containing the specified MD RAIDs
      def create_mds(mds, previous_result, devs_to_reuse)
        mds.reduce(previous_result) do |result, md|
          # Normally, the profile will use the same naming convention
          # (/dev/md0 vs /dev/md/0) to define the RAID itself (in its corresponding
          # <drive> section) and to reference that RAID from its components
          # (using <raid_name>). So populating the 'devices' list below could be
          # as simple as matching Planned::Devices#raid_name with Planned::Md.name
          #
          # BUT if the old format is used to specify the RAID ("/dev/md" as name
          # and a <partition_nr> to indicate the number), the name for the planned MD
          # is auto-generated (with the /dev/md/0 format so far), so we must use
          # Planned::Md#name? to ensure robust comparison no matter which format
          # is used in #raid_name
          devices = result.created_names { |d| d.respond_to?(:raid_name) && md.name?(d.raid_name) }
          devices += devs_to_reuse.select { |d| md.name?(d.raid_name) }.map(&:reuse_name)
          result.merge(create_md(result.devicegraph, md, devices))
        end
      end

      # Creates a Bcaches in the given devicegraph
      #
      # @param bcaches         [Array<Planned::Bcache>] List of planned MD arrays to create
      # @param previous_result [Proposal::CreatorResult] Starting point
      # @param devs_to_reuse   [Array<Planned::Partition, Planned::StrayBlkDevice>] List of devices
      #   to reuse
      # @return                [Proposal::CreatorResult] Result containing the specified MD RAIDs
      def create_bcaches(bcaches, previous_result, devs_to_reuse)
        bcaches.reduce(previous_result) do |result, bcache|
          backing_devname = find_bcache_member(bcache.name, :backing, previous_result, devs_to_reuse)
          caching_devname = find_bcache_member(bcache.name, :caching, previous_result, devs_to_reuse)
          new_result = create_bcache(result.devicegraph, bcache, backing_devname, caching_devname)
          result.merge(new_result)
        end
      end

      # Create a MD RAID
      #
      # @param devicegraph [Devicegraph] Starting devicegraph
      # @param md          [Planned::Md] Planned MD RAID
      # @param devices     [Array<Planned::Device>] List of devices to include in the RAID
      # @return            [Proposal::CreatorResult] Result containing the specified RAID
      #
      # @raise NoDiskSpaceError
      def create_md(devicegraph, md, devices)
        md_creator = Proposal::MdCreator.new(devicegraph)
        md_creator.create_md(md, devices)
      rescue NoDiskSpaceError
        md_creator = Proposal::MdCreator.new(devicegraph)
        new_md = md.clone
        new_md.partitions = flexible_devices(md.partitions)
        md_creator.create_md(new_md, devices)
      end

      # Creates a Bcache
      #
      # @param devicegraph     [Devicegraph] Starting devicegraph
      # @param bcache          [Planned::Bcache] Planned Bcache
      # @param backing_devname [String] Backing device name
      # @param caching_devname [String] Caching device name
      # @return [Proposal::CreatorResult] Result containing the specified Bcache
      def create_bcache(devicegraph, bcache, backing_devname, caching_devname)
        bcache_creator = Proposal::BcacheCreator.new(devicegraph)
        bcache_creator.create_bcache(bcache, backing_devname, caching_devname)
      rescue NoDiskSpaceError
        bcache_creator = Proposal::BcacheCreator.new(devicegraph)
        new_bcache = bcache.clone
        new_bcache.partitions = flexible_devices(bcache.partitions)
        bcache_creator.create_bcache(new_bcache, backing_devname, caching_devname)
      end

      # Finds the bcache member in the previous result and the list of devices to use
      #
      # @return [String] Device name
      def find_bcache_member(bcache_name, role, result, devs_to_reuse)
        names = result.created_names { |d| bcache_member_for?(d, bcache_name, role) }
        return names.first unless names.empty?
        device = devs_to_reuse.find { |d| bcache_member_for?(d, bcache_name, role) }
        device && device.reuse_name
      end

      # Determines whether a device plays a given role in a Bcache
      #
      # @param device      [Planned::Device] Device to consider
      # @param bcache_name [String] Bcache name
      # @param role        [:caching, :backing] Role that the device plays in the Bcache device
      # @return [Boolean]
      def bcache_member_for?(device, bcache_name, role)
        query_method = "bcache_#{role}_for?"
        device.respond_to?(query_method) && device.send(query_method, bcache_name)
      end

      # Return a new planned devices with flexible limits
      #
      # The min_size is removed and a proportional weight is set for every device.
      #
      # @return [Hash<Planned::Partition => Planned::Partition>]
      def flexible_devices(devices)
        devices.map do |device|
          new_device = device.clone
          new_device.weight = device.min_size.to_i
          new_device.min_size = DiskSize.B(1)
          new_device
        end
      end

      # Return devices which can be reused by an MD RAID
      #
      # @param planned_devices [Planned::DevicesCollection] collection of planned devices
      # @return [Array<Planned::Device>]
      def reusable_by_md(planned_devices)
        planned_devices.select { |d| d.respond_to?(:raid_name) }
      end

      # Return devices which can be reused by a Bcache
      #
      # @param planned_devices [Planned::DevicesCollection] collection of planned devices
      # @return [Array<Planned::Device>]
      def reusable_by_bcache(planned_devices)
        planned_devices.select { |d| d.respond_to?(:bcache_backing_for) }
      end

      # Returns a list of planned partitions adjusting the size
      #
      # All partitions which sizes are specified as percentage will get their minimal and maximal
      # sizes adjusted.
      #
      # @param planned_partitions [Array<Planned::Partition>] List of planned partitions
      # @return [Array<Planned::Partition>] New list of planned partitions with adjusted sizes
      def sized_partitions(planned_partitions)
        planned_partitions.map do |part|
          new_part = part.clone
          next new_part unless new_part.percent_size
          disk = original_graph.find_by_name(part.disk)
          new_part.max = new_part.min = new_part.size_in(disk)
          new_part
        end
      end
    end
  end
end
