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
require "y2storage/proposal/encrypter"

module Y2Storage
  class Proposal
    # Class to create partitions following a given distribution represented by
    # a SpaceDistribution object
    class PartitionCreator
      using Refinements::Devicegraph
      using Refinements::DevicegraphLists
      using Y2Storage::Refinements::Disk
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
          process_free_space(space.disk_space, space.volumes, space.usable_size, space.num_logical)
        end

        devicegraph
      end

    private

      # Working devicegraph
      attr_accessor :devicegraph
      attr_reader :original_graph

      # Create partitions in a single slot of free disk space.
      #
      # @param free_space [FreeDiskSpace] the slot
      # @param volumes   [PlannedVolumesList] volumes to create
      # @params usable_size [DiskSize] real space to distribute among the
      #       volumes (part of free_space could be used for data structures)
      # @param num_logical [Integer] how many volumes should be placed in
      #       logical partitions
      def process_free_space(free_space, volumes, usable_size, num_logical)
        volumes.each do |vol|
          log.info(
            "vol #{vol.mount_point}\tmin: #{vol.min_disk_size}\tmax: #{vol.max_disk_size} " \
            "desired: #{vol.desired_disk_size}\tweight: #{vol.weight}"
          )
        end

        min_grain = free_space.disk.min_grain
        sorted = sorted_volumes(volumes, usable_size, min_grain)
        volumes = sorted.distribute_space(usable_size, min_grain: min_grain)
        create_volumes_partitions(volumes, free_space, num_logical)
      end

      # Volumes sorted in the most convenient way in order to create partitions
      # for them.
      def sorted_volumes(volumes, usable_size, min_grain)
        sorted = volumes.sort_by_attr(:disk, :max_start_offset)
        last = volumes.enforced_last(usable_size, min_grain)
        if last
          sorted.delete(last)
          sorted << last
        end
        PlannedVolumesList.new(sorted, target: volumes.target)
      end

      # Creates a partition and the corresponding filesystem for each volume
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
      # @param num_logical [Symbol] logical partitions @see #process_space
      def create_volumes_partitions(volumes, initial_free_space, num_logical)
        volumes.each_with_index do |vol, idx|
          partition_id = vol.partition_id
          partition_id ||= vol.mount_point == "swap" ? ::Storage::ID_SWAP : ::Storage::ID_LINUX
          begin
            space = free_space_within(initial_free_space)
            primary = volumes.size - idx > num_logical
            partition = create_partition(vol, partition_id, space, primary)
            final_device = encrypter.device_for(vol, partition)
            filesystem = vol.create_filesystem(final_device)
            if vol.subvolumes?
              other_mount_points = volumes.map { |v| v.mount_point }
              other_mount_points.delete_if { |mp| mp == vol.mount_point }
              vol.create_subvolumes(filesystem, other_mount_points)
            end
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
        disk = devicegraph.disks.with(name: initial_free_space.disk_name).first
        spaces = disk.as_not_empty { disk.free_spaces }.select do |space|
          space.region.start >= initial_free_space.region.start &&
            space.region.start < initial_free_space.region.end
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
        ptable = partition_table(disk)

        if primary
          dev_name = next_free_primary_partition_name(disk.name, ptable)
          partition_type = ::Storage::PartitionType_PRIMARY
        else
          if !ptable.has_extended
            create_extended_partition(disk, free_space.region)
            free_space = free_space_within(free_space)
          end
          dev_name = next_free_logical_partition_name(disk.name, ptable)
          partition_type = ::Storage::PartitionType_LOGICAL
        end

        region = new_region_with_size(free_space.region, vol.disk_size)
        partition = ptable.create_partition(dev_name, region, partition_type)
        partition.id = partition_id
        partition.boot = !!vol.bootable if ptable.partition_boot_flag_supported?
        partition
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

      # Create a new region from the given one, but with new size
      # disk_size.
      #
      # @param region [::Storage::Region] initial region
      # @param disk_size [DiskSize] new size of the region
      #
      # @return [::Storage::Region] Newly created region
      #
      def new_region_with_size(region, disk_size)
        blocks = disk_size.to_i / region.block_size
        # Never exceed the region
        if region.start + blocks > region.end
          blocks = region.end - region.start + 1
        end
        # region.dup doesn't seem to work (SWIG bindings problem?)
        ::Storage::Region.new(region.start, blocks, region.block_size)
      end

      # Returns the partition table for disk, creating an empty one if needed
      #
      # @param [Storage::Disk]
      # @return [Storage::PartitionTable]
      def partition_table(disk)
        disk.partition_table
      rescue Storage::WrongNumberOfChildren
        disk.create_partition_table(disk.preferred_ptable_type)
      end

      def encrypter
        @encrypter ||= Encrypter.new
      end
    end
  end
end
