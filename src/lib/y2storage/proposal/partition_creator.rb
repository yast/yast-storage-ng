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
require "y2storage/planned_volumes_list"
require "y2storage/disk_size"
require "y2storage/refinements"

module Y2Storage
  class Proposal
    # Class to create partitions following a given distribution represented by
    # a SpaceDistribution object
    class PartitionCreator
      using Refinements::Devicegraph
      using Refinements::DevicegraphLists
      include Yast::Logger

      FIRST_LOGICAL_PARTITION_NUMBER = 5 # Number of the first logical partition (/dev/sdx5)

      # Initialize.
      #
      # @param original_graph [::Storage::Devicegraph] initial devicegraph
      def initialize(original_graph)
        @original_graph = original_graph
      end

      # Returns a copy of the original devicegraph in which all the needed
      # partitions have been created.
      #
      # @param distribution [SpaceDistribution]
      # @return [::Storage::Devicegraph]
      def create_partitions(distribution)
        self.devicegraph = original_graph.duplicate

        distribution.spaces.each do |space|
          type = space.partition_type
          vols = space.volumes
          disk_space = space.disk_space
          process_space(vols, disk_space, type)
        end

        devicegraph
      end

    private

      # Working devicegraph
      attr_accessor :devicegraph
      attr_reader :original_graph

      # Create partitions without LVM in a single slot of free disk space.
      #
      # @param volumes   [PlannedVolumesList] volumes to create
      # @param free_space [FreeDiskSpace]
      # @param partition_type [Symbol] type to be enforced to all the
      #       partitions. If nil, each partition can have a different type
      def process_space(volumes, free_space, partition_type)
        volumes.each do |vol|
          log.info(
            "vol #{vol.mount_point}\tmin: #{vol.min_disk_size}\tmax: #{vol.max_disk_size} " \
            "desired: #{vol.desired_disk_size}\tweight: #{vol.weight}"
          )
        end

        volumes = volumes.distribute_space(free_space.disk_size)
        create_volumes_partitions(volumes, free_space, partition_type)
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
      # @param partition_type [Symbol] @see #create_non_lvm_simple
      def create_volumes_partitions(volumes, initial_free_space, partition_type)
        volumes.sort_by_attr(:disk, :max_start_offset).each do |vol|
          partition_id = vol.partition_id
          partition_id ||= vol.mount_point == "swap" ? ::Storage::ID_SWAP : ::Storage::ID_LINUX
          begin
            space = free_space_within(initial_free_space)
            primary = primary?(partition_type, space.disk)
            partition = create_partition(vol, partition_id, space, primary)
            vol.create_filesystem(partition)
            devicegraph.check
          rescue ::Storage::Exception => error
            raise Error, "Error allocating #{vol}. Details: #{error}"
          end
        end
      end

      def primary?(partition_type, disk)
        if partition_type.nil?
          !logical_partition_preferred?(disk.partition_table)
        else
          partition_type == :primary
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
        log.info("Creating partition for #{vol.mount_point} with #{vol.disk_size}")
        disk = free_space.disk
        ptable = disk.partition_table

        if primary
          dev_name = next_free_primary_partition_name(disk.name, ptable)
          partition_type = ::Storage::PartitionType_PRIMARY
        else
          if !ptable.has_extended
            create_extended_partition(disk, free_space.slot.region)
            free_space = free_space_within(free_space)
          end
          dev_name = next_free_logical_partition_name(disk.name, ptable)
          partition_type = ::Storage::PartitionType_LOGICAL
        end

        region = new_region_with_size(free_space.slot, vol.disk_size)
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
        blocks = disk_size.to_i / region.block_size
        # Never exceed the region
        if region.start + blocks > region.end
          blocks = region.end - region.start + 1
        end
        # region.dup doesn't seem to work (SWIG bindings problem?)
        ::Storage::Region.new(region.start, blocks, region.block_size)
      end
    end
  end
end
