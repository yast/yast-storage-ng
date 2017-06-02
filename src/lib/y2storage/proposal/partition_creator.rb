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
require "y2storage/planned"
require "y2storage/disk_size"
require "y2storage/proposal/encrypter"

module Y2Storage
  module Proposal
    # Class to create partitions following a given distribution represented by
    # a Planned::PartitionsDistribution object
    class PartitionCreator
      include Yast::Logger

      FIRST_LOGICAL_PARTITION_NUMBER = 5 # Number of the first logical partition (/dev/sdx5)

      # Initialize.
      #
      # @param original_graph [Devicegraph] initial devicegraph
      def initialize(original_graph)
        @original_graph = original_graph
      end

      # Returns a copy of the original devicegraph in which all the needed
      # partitions have been created.
      #
      # @param distribution [Planned::PartitionsDistribution]
      # @return [Devicegraph]
      def create_partitions(distribution)
        self.devicegraph = original_graph.duplicate

        distribution.spaces.each do |space|
          process_free_space(space.disk_space, space.partitions, space.usable_size, space.num_logical)
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
      # @param partitions [Array<Planned::Partition>] partitions to create
      # @param usable_size [DiskSize] real space to distribute among the planned
      #       partitions (part of free_space could be used for data structures)
      # @param num_logical [Integer] how many partitions should be logical
      def process_free_space(free_space, partitions, usable_size, num_logical)
        partitions.each do |p|
          log.info "partition #{p.mount_point}\tmin: #{p.min}\tmax: #{p.max}\tweight: #{p.weight}"
        end

        min_grain = free_space.disk.min_grain
        partitions = Planned::Partition.distribute_space(partitions, usable_size, min_grain: min_grain)
        create_planned_partitions(partitions, free_space, num_logical)
      end

      # Creates a partition and the corresponding filesystem for each planned
      # partition
      #
      # @raise an error if a partition cannot be allocated
      #
      # It tries to honor the value of #max_start_offset for each partition, but
      # it does not raise an exception if that particular requirement is
      # impossible to fulfill, since it's usually more a recommendation than a
      # hard limit.
      #
      # @param planned_partitions [Array<Planned::Partition>]
      # @param initial_free_space [FreeDiskSpace]
      # @param num_logical [Symbol] logical partitions. See {#process_space}
      def create_planned_partitions(planned_partitions, initial_free_space, num_logical)
        planned_partitions.each_with_index do |part, idx|
          partition_id = part.partition_id
          partition_id ||= part.mount_point == "swap" ? PartitionId::SWAP : PartitionId::LINUX
          begin
            space = free_space_within(initial_free_space)
            primary = planned_partitions.size - idx > num_logical
            partition = create_partition(part, partition_id, space, primary)
            final_device = encrypter.device_for(part, partition)
            part.create_filesystem(final_device)
            devicegraph.check
          rescue ::Storage::Exception => error
            raise Error, "Error allocating #{part}. Details: #{error}"
          end
        end
      end

      # Finds the remaining free space within the scope of the disk chunk
      # defined by a (probably outdated) FreeDiskSpace object
      #
      # @param initial_free_space [FreeDiskSpace] the original disk chunk, the
      #   returned free space will be within this area
      def free_space_within(initial_free_space)
        disk = devicegraph.disks.detect { |d| d.name == initial_free_space.disk_name }
        spaces = disk.as_not_empty { disk.free_spaces }.select do |space|
          space.region.start >= initial_free_space.region.start &&
            space.region.start < initial_free_space.region.end
        end
        raise NoDiskSpaceError, "Exhausted free space" if spaces.empty?
        spaces.first
      end

      # Create a real partition for the specified planned partition within the
      # specified slot of free space.
      #
      # @param planned_partition [Planned::Partition]
      # @param partition_id [PartitionId]
      # @param free_space   [FreeDiskSpace]
      # @param primary      [Boolean] whether the partition should be primary
      #                     or logical
      #
      def create_partition(planned_partition, partition_id, free_space, primary)
        log.info "Creating partition for #{planned_partition.mount_point} with #{planned_partition.size}"
        disk = free_space.disk
        ptable = partition_table(disk)

        if primary
          dev_name = next_free_primary_partition_name(disk.name, ptable)
          partition_type = PartitionType::PRIMARY
        else
          if !ptable.has_extended?
            create_extended_partition(disk, free_space.region)
            free_space = free_space_within(free_space)
          end
          dev_name = next_free_logical_partition_name(disk.name, ptable)
          partition_type = PartitionType::LOGICAL
        end

        region = new_region_with_size(free_space.region, planned_partition.size)
        partition = ptable.create_partition(dev_name, region, partition_type)
        partition.id = partition_id
        partition.boot = !!planned_partition.bootable if ptable.partition_boot_flag_supported?
        partition
      end

      # Creates an extended partition
      #
      # @param disk [Disk]
      # @param region [Region]
      def create_extended_partition(disk, region)
        ptable = disk.partition_table
        dev_name = next_free_primary_partition_name(disk.name, ptable)
        ptable.create_partition(dev_name, region, PartitionType::EXTENDED)
      end

      # Return the next device name for a primary partition that is not already
      # in use.
      #
      # @return [String] device_name ("/dev/sdx1", "/dev/sdx2", ...)
      #
      def next_free_primary_partition_name(disk_name, ptable)
        # FIXME: This is broken by design. create_partition needs to return
        # this information, not get it as an input parameter.
        part_names = ptable.partitions.map(&:name)
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
        part_names = ptable.partitions.map(&:name)
        FIRST_LOGICAL_PARTITION_NUMBER.upto(ptable.max_logical) do |i|
          dev_name = "#{disk_name}#{i}"
          return dev_name unless part_names.include?(dev_name)
        end
        raise NoMorePartitionSlotError
      end

      # Create a new region from the given one, but with new size.
      #
      # @param region [Region] initial region
      # @param size [DiskSize] new size of the region
      #
      # @return [Region] Newly created region
      #
      def new_region_with_size(region, size)
        blocks = (size / region.block_size).to_i
        # Never exceed the region
        if region.start + blocks > region.end
          blocks = region.end - region.start + 1
        end
        Region.create(region.start, blocks, region.block_size)
      end

      # Returns the partition table for disk, creating an empty one if needed
      #
      # @param disk [Disk]
      # @return [PartitionTable]
      def partition_table(disk)
        disk.partition_table || disk.create_partition_table(disk.preferred_ptable_type)
      end

      def encrypter
        @encrypter ||= Encrypter.new
      end
    end
  end
end
