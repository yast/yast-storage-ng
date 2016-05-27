#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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

require "fileutils"
require "storage/planned_volumes_list"
require "storage/disk_size"
require "storage/refinements/devicegraph"
require "storage/refinements/devicegraph_lists"
require "storage/proposal/volumes_distribution"

module Yast
  module Storage
    class Proposal
      # Class to create partitions in the free space detected or freed by the
      # SpaceMaker.
      class PartitionCreator
        using Refinements::Devicegraph
        using Refinements::DevicegraphLists
        include Yast::Logger

        attr_accessor :settings

        VOLUME_GROUP_SYSTEM = "system"
        FIRST_LOGICAL_PARTITION_NUMBER = 5 # Number of the first logical partition (/dev/sdx5)

        # Initialize.
        #
        # @param original_graph [::Storage::Devicegraph] initial devicegraph
        # @param settings [Proposal::Settings] proposal settings
        def initialize(original_graph, settings)
          @original_graph = original_graph
          @settings = settings
        end

        # Returns a copy of the original devicegraph in which all the needed
        # partitions have been created.
        #
        # @param volumes [PlannedVolumesList] volumes to create
        # @param target_size [Symbol] :desired or :min
        # @return [::Storage::Devicegraph]
        def create_partitions(distribution, target_size)
          self.devicegraph = original_graph.copy

          # FIXME: not implemented yet in libstorage-bgl
          # use_lvm = settings.use_lvm
          use_lvm = false

          if use_lvm
            raise NotImplementedError
            create_lvm(distribution, target_size)
          else
            create_non_lvm(distribution, target_size)
          end
          devicegraph
        end

      private

        # Working devicegraph
        attr_accessor :devicegraph
        attr_reader :original_graph

        # List of free spaces in the devicegraph
        #
        # @return [FreeDiskSpacesList]
        def free_spaces
          candidate_disks.free_disk_spaces
        end

        # @return [Array<String>]
        def candidate_disk_names
          settings.candidate_devices
        end

        # Query in the target devicegraph restricted to the candidate disks
        #
        # @return [DisksList]
        def candidate_disks
          @candidate_disks ||= devicegraph.disks.with(name: candidate_disk_names)
        end

        # Create volumes on LVM.
        #
        # @param volumes [Array<ProposalVolume>] volumes to create
        # @param strategy [Symbol] :desired or :min
        #
        def create_lvm(volumes, strategy)
          lvm_vol, non_lvm_vol = volumes.partition(&:can_live_on_logical_volume)
          # Create any partitions first that cannot be created on LVM
          # to avoid LVM consuming all the available free space
          create_non_lvm(non_lvm_vol, strategy)

          return if lvm_vol.empty?

          # Create LVM partitions (using the rest of the available free space)
          volume_group = create_volume_group(VOLUME_GROUP_SYSTEM)
          create_physical_volumes(volume_group)
          lvm_vol.each { |vol| create_logical_volume(volume_group, vol, strategy) }
        end

        # Create partitions without LVM.
        #
        # @param volumes  [Array<ProposalVolume] volumes to create
        # @param strategy [Symbol] :desired or :min_size
        #
        def create_non_lvm(distribution, strategy)
          distribution.volumes_lists.each do |space, vols|
            type = distribution.space_types[:space]
            create_non_lvm_simple(vols, space, strategy, type)
          end
        end

        # Create partitions without LVM in a single slot of free disk space.
        #
        # @param volumes   [PlannedVolumesList] volumes to create
        # @param free_space [FreeDiskSpace]
        # @param strategy  [Symbol] :desired or :min_size
        # @param partitions_type [Symbol] type to be enforced to all the
        #       partitions. If nil, each partition can have a different type
        def create_non_lvm_simple(volumes, free_space, strategy, partitions_type)
          volumes.each do |vol|
            log.info(
              "vol #{vol.mount_point}\tmin: #{vol.min_size} " \
              "max: #{vol.max_size} desired: #{vol.desired_size} weight: #{vol.weight}"
            )
          end

          volumes = volumes.deep_dup
          volumes.each { |vol| vol.size = vol.min_valid_size(strategy) }
          distribute_extra_space(volumes, free_space)
          create_volumes_partitions(volumes, free_space, partitions_type)
        end

        # Distribute extra disk space among the specified volumes. This updates
        # the size of each volume with the distributed space.
        #
        # @param volumes [PlannedVolumesList]
        # @param space   [FreeDiskSpace]
        #
        # @return [DiskSpace] remaining space that could not be distributed
        #
        def distribute_extra_space(volumes, space)
          candidates = volumes
          extra_size = space.size - volumes.total_size
          while extra_size > DiskSize.zero
            candidates = extra_space_candidates(candidates)
            return extra_size if candidates.empty?
            return extra_size if candidates.total_weight.zero?
            log.info("Distributing #{extra_size} extra space among #{candidates.size} volumes")

            assigned_size = DiskSize.zero
            candidates.each do |vol|
              vol_extra = volume_extra_size(vol, extra_size, candidates.total_weight)
              vol.size += vol_extra
              log.info("Distributing #{vol_extra} to #{vol.mount_point}; now #{vol.size}")
              assigned_size += vol_extra
            end
            extra_size -= assigned_size
          end
          log.info("Could not distribute #{extra_size}") unless extra_size.zero?
          extra_size
        end

        # Volumes that may grow when distributing the extra space
        #
        # @param volumes [PlannedVolumesList] initial set of all volumes
        # @return [PlannedVolumesList]
        def extra_space_candidates(volumes)
          candidates = volumes.dup
          candidates.delete_if { |vol| vol.size >= vol.max_size }
          candidates
        end

        # Extra space to be assigned to a volume
        #
        # @param volume [PlannedVolume] volume to enlarge
        # @param available_size [DiskSize] free space to be distributed among
        #    involved volumes
        # @param total_weight [Float] sum of the weights of all involved volumes
        #
        # @return [DiskSize]
        def volume_extra_size(volume, available_size, total_weight)
          extra_size = available_size * (volume.weight / total_weight)
          new_size = extra_size + volume.size
          if new_size > volume.max_size
            # Increase just until reaching the max size
            volume.max_size - volume.size
          else
            extra_size
          end
        end

        # Creates a partition and the corresponding filesystem for each volume
        #
        # Important: notice that, so far, this method is only intended to work
        # in cases in which there is only one chunk of free space in the system.
        #
        # @raise an error if a volume cannot be allocated
        #
        # It tries to honor the value of #max_start_offset for each volume, but
        # it does not raise an exception if that particular requirement is
        # impossible to fulfill, since it's usually more a recommendation than a
        # hard limit.
        #
        # @param volumes [Array<PlannedVolume>]
        # @param initial_free_space [FreeDiskSpace]
        # @param partitions_type [Symbol] @see #create_non_lvm_simple
        def create_volumes_partitions(volumes, initial_free_space, partitions_type)
          volumes.sort_by_attr(:disk, :max_start_offset).each do |vol|
            partition_id = vol.partition_id
            partition_id ||= vol.mount_point == "swap" ? ::Storage::ID_SWAP : ::Storage::ID_LINUX
            begin
              space = free_space_within(initial_free_space)
              if partitions_type.nil?
                primary = !logical_partition_preferred?(space.disk.partition_table)
              else
                primary = partitions_type == :primary
              end
              partition = create_partition(vol, partition_id, space, primary)
              make_filesystem(partition, vol)
              devicegraph.check
            rescue ::Storage::Exception => error
              raise Error, "Error allocating #{vol}. Details: #{error}"
            end
          end
        end

        # Finds the remaining free space within the scope of the disk chunk
        # defined by a (probably outdated) FreeDiskSpace object
        #
        # @param [FreeDiskSpace] the original disk chunk, the returned free
        #   space will be within this area
        def free_space_within(initial_free_space)
          disks = devicegraph.disks.with(name: initial_free_space.disk_name)
          spaces = disks.free_disk_spaces.with do |space|
            space.slot.region.start >= initial_free_space.slot.region.start &&
              space.slot.region.start < initial_free_space.slot.region.end
          end
          raise NoDiskSpaceError, "Exhausted free space" if spaces.empty?
          spaces.first
        end

        # Create a partition for the specified volume within the specified slot
        # of free space.
        #
        # @param vol          [ProposalVolume]
        # @param partition_id [::Storage::IdNum] ::Storage::ID_Linux etc.
        # @param free_space   [FreeDiskSpace]
        # @param primary      [Boolean] whether the partition should be primary
        #                     or logical
        #
        def create_partition(vol, partition_id, free_space, primary)
          log.info("Creating partition for #{vol.mount_point} with #{vol.size}")
          disk = free_space.disk
          ptable = disk.partition_table

          if primary
            dev_name = next_free_primary_partition_name(disk.name, ptable)
            partition_type = ::Storage::PartitionType_PRIMARY
          else
            create_extended_partition(disk, free_space.slot.region) unless ptable.has_extended
            dev_name = next_free_logical_partition_name(disk.name, ptable)
            partition_type = ::Storage::PartitionType_LOGICAL
          end

          region = new_region_with_size(free_space.slot, vol.size)
          partition = ptable.create_partition(dev_name, region, partition_type)
          partition.id = partition_id
          partition.boot = !!vol.bootable
          partition
        end

        # Checks if the next partition to be created should be a logical one
        #
        # @param ptable [Storage::PartitionTable]
        # @return [Boolean] true for logical partition, false if primary is
        #       preferred
        def logical_partition_preferred?(ptable)
          ptable.extended_possible && ptable.num_primary >= ptable.max_primary - 1
        end

        # Creates an extended partition
        #
        # @param disk [Storage::Disk]
        # @param region [Storage::Region]
        def create_extended_partition(disk, region)
          ptable = disk.partition_table
          dev_name = next_free_primary_partition_name(disk.name, ptable)
          ptable.create_partition(dev_name, region, ::Storage::PartitionType_EXTENDED)
        end

        # Return the next device name for a primary partition that is not already
        # in use.
        #
        # @return [String] device_name ("/dev/sdx1", "/dev/sdx2", ...)
        #
        def next_free_primary_partition_name(disk_name, ptable)
          # FIXME: This is broken by design. create_partition needs to return
          # this information, not get it as an input parameter.
          part_names = ptable.partitions.to_a.map(&:name)
          1.upto(ptable.max_primary) do |i|
            dev_name = "#{disk_name}#{i}"
            return dev_name unless part_names.include?(dev_name)
          end
          raise NoMorePartitionSlotError
        end

        # Return the next device name for a logical partition that is not already
        # in use. The first one is always /dev/sdx5.
        #
        # @return [String] device_name ("/dev/sdx5", "/dev/sdx6", ...)
        #
        def next_free_logical_partition_name(disk_name, ptable)
          # FIXME: This is broken by design. create_partition needs to return
          # this information, not get it as an input parameter.
          part_names = ptable.partitions.to_a.map(&:name)
          FIRST_LOGICAL_PARTITION_NUMBER.upto(ptable.max_logical) do |i|
            dev_name = "#{disk_name}#{i}"
            return dev_name unless part_names.include?(dev_name)
          end
          raise NoMorePartitionSlotError
        end

        # Create a new region from the one in free_slot, but with new size
        # disk_size.
        #
        # @param free_slot [::Storage::PartitionSlot]
        # @param disk_size [DiskSize] new size of the region
        #
        # @return [::Storage::Region] Newly created region
        #
        def new_region_with_size(free_slot, disk_size)
          region = free_slot.region
          blocks = (1024 * disk_size.size_k) / region.block_size
          # region.dup doesn't seem to work (SWIG bindings problem?)
          ::Storage::Region.new(region.start, blocks, region.block_size)
        end

        # Create a filesystem for the specified volume on the specified partition
        # and set its mount point. Do nothing if there is no filesystem
        # configured for 'vol'.
        #
        # @param partition [::Storage::Partition]
        # @param vol       [ProposalVolume]
        #
        # @return [::Storage::Filesystem] filesystem
        #
        def make_filesystem(partition, vol)
          return nil unless vol.filesystem_type
          filesystem = partition.create_filesystem(vol.filesystem_type)
          filesystem.add_mountpoint(vol.mount_point) if vol.mount_point && !vol.mount_point.empty?
          filesystem.label = vol.label if vol.label
          filesystem.uuid = vol.uuid if vol.uuid
          filesystem
        end

        # Create an LVM volume group.
        #
        # @param volume_group_name [String]
        #
        # @return [::Storage::VolumeGroup] volume_group
        #
        def create_volume_group(volume_group_name)
          log.info("Creating LVM volume group #{volume_group_name}")
          # TODO
          raise NotImplementedError
        end

        # Create LVM physical volumes for all the rest of free_space and add them
        # to the specified volume group.
        #
        # @param volume_group [::Storage::VolumeGroup]
        #
        def create_physical_volumes(volume_group)
          log.info("Creating LVM physical volumes for #{volume_group}")
        end

        # Create an LVM logical volume in the specified volume group for vol.
        #
        # @param volume_group [::Storage::VolumeGroup]
        # @param vol          [ProposalVolume]
        # @param strategy     [Symbol] :desired or :min_size
        #
        def create_logical_volume(volume_group, vol, strategy)
          log.info(
            "Creating LVM logical volume #{vol.logical_volume_name} at #{volume_group} "\
            "with strategy \"#{strategy}\""
          )
          # TO DO
          # TO DO
          # TO DO
        end
      end
    end
  end
end
