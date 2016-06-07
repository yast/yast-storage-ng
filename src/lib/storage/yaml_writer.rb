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

require "yast"
require "yaml"
require "storage"
require "storage/disk_size.rb"
require "storage/enum_mappings.rb"

module Yast
  module Storage
    #
    # Class to write storage device trees to YAML files.
    #
    class YamlWriter
      include Yast::Logger
      include EnumMappings

      class << self
        #
        # Write all devices from the specified device graph to a YAML file.
        #
        # This is a singleton method for convenience. It creates a YamlWriter
        # internally for one-time usage. If you use this more often (for
        # example, in a loop), it is recommended to use create a YamlWriter and
        # use its write() method repeatedly.
        #
        # @param devicegraph [::Storage::devicegraph]
        # @param yaml_file [String | IO]
        #
        def write(devicegraph, yaml_file)
          writer = YamlWriter.new
          writer.write(devicegraph, yaml_file)
        end
      end

      def initialize
        # Cache some frequently needed values: We need the inverse mapping from
        # EnumMappings, i.e. from the C++ enum to string.
        @partition_table_types = PARTITION_TABLE_TYPES.invert
        @partition_types       = PARTITION_TYPES.invert
        @partition_ids         = PARTITION_IDS.invert
        @file_system_types     = FILE_SYSTEM_TYPES.invert
      end

      # Write all devices from the specified device graph to a YAML file.
      #
      # @param devicegraph [::Storage::devicegraph]
      # @param yaml_file [String | IO]
      #
      def write(devicegraph, yaml_file)
        device_tree = yaml_device_tree(devicegraph)
        if yaml_file.respond_to?(:write)
          yaml_file.write(device_tree.to_yaml)
        else
          File.open(yaml_file, "w") { |file| file.write(device_tree.to_yaml) }
        end
      end

      # Convert all devices from the specified device graph to YAML data
      # structures, i.e. nested arrays and hashes. The toplevel item will
      # always be an array.
      #
      # @param devicegraph [::Storage::devicegraph]
      # @return [Array<Hash>]
      #
      def yaml_device_tree(devicegraph)
        devicegraph.all_disks.to_a.inject([]) { |yaml, disk| yaml << yaml_disk(disk) }
      end

    private

      # Return the YAML counterpart of a ::Storage::Disk.
      #
      # @param  disk [::Storage::Disk]
      # @return [Hash]
      #
      def yaml_disk(disk)
        content = {}
        content["size"] = DiskSize.B(disk.size).to_s_ex
        content["block_size"] = DiskSize.B(disk.region.block_size).to_s_ex
        content["io_size"] = DiskSize.B(disk.topology.optimal_io_size).to_s_ex
        content["min_grain"] = DiskSize.B(disk.topology.minimal_grain).to_s_ex
        content["align_ofs"] = DiskSize.B(disk.topology.alignment_offset).to_s_ex
        content["name"] = disk.name
        begin
          ptable = disk.partition_table # this will raise an excepton if no partition table
          content["partition_table"] = @partition_table_types[ptable.type]
          if ::Storage.msdos?(ptable)
            content["mbr_gap"] = DiskSize.B(::Storage.to_msdos(ptable).minimal_mbr_gap).to_s_ex
          end
          partitions = yaml_disk_partitions(disk)
          content["partitions"] = partitions unless partitions.empty?
        rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
          log.info("CAUGHT exception #{ex}")
        end

        { "disk" => content }
      end

      # Returns a YAML representation of the partitions and free slots in a disk
      #
      # Free slots are calculated as best as we can and not part of the
      # partition table object.
      #
      # @param disk [::Storage::Disk]
      # @return [Array<Hash>]
      def yaml_disk_partitions(disk)
        partition_end = 0
        partition_end_max = 0
        partition_end_ext = 0
        partitions = []
        sorted_parts = sorted_partitions(disk)
        sorted_parts.each do |partition|

          # if we are about to leave an extend partition, show what's left
          if partition_end_ext > 0 && partition.type != ::Storage::PartitionType_LOGICAL
            gap = partition_end_ext - partition_end;
            partitions << yaml_free_slot(DiskSize.B(partition_end_ext - gap), DiskSize.B(gap)) if gap > 0
            partition_end = partition_end_ext
            partition_end_ext = 0
          end

          # is there a gap before the partition?
          # note: gap might actually be negative sometimes!
          gap = partition.region.start * partition.region.block_size - partition_end;
          partitions << yaml_free_slot(DiskSize.B(partition_end), DiskSize.B(gap)) if gap > 0

          # show partition itself
          partitions << yaml_partition(partition)

          # adjust end pointers
          partition_end = (partition.region.end + 1) * partition.region.block_size
          partition_end_max = [ partition_end_max, partition_end].max

          # if we're inside an extended partition, remember its end for later
          if partition.type == ::Storage::PartitionType_EXTENDED
            partition_end_ext = partition_end
          end
        end

        # finally, show what's left

        # see if there's space left in an extended partition
        if partition_end_ext > 0
          gap = partition_end_ext - partition_end;
          partitions << yaml_free_slot(DiskSize.B(partition_end_ext), DiskSize.B(gap)) if gap > 0
        end

         # see if there's space left at the end of the disk
        gap = (disk.region.end + 1) * disk.region.block_size - partition_end_max
        partitions << yaml_free_slot(DiskSize.B(partition_end_max), DiskSize.B(gap)) if gap > 0

        partitions
      end

      # Partitions sorted by position in the disk and by type
      #
      # Start position is the primary criteria. In addition, extended partitions
      # are listed before any of its corresponding logical partitions
      #
      # @param disk [::Storage::Disk]
      # @return [Array<::Storage::Partition>]
      def sorted_partitions(disk)
        disk.partition_table.partitions.to_a.sort do |a, b|
          by_start = a.region.start <=> b.region.start
          if by_start.zero?
            a.type == ::Storage::PartitionType_EXTENDED ? 1 : -1
          else
            by_start
          end
        end
      end

      #
      # Return the YAML counterpart of a ::Storage::Partition.
      #
      # @param  partition [::Storage::Partition]
      # @return [Hash]
      #
      # rubocop:disable Metrics/AbcSize
      def yaml_partition(partition)
        content = {
          "size" => DiskSize.B(partition.region.length * partition.region.block_size).to_s_ex,
          "start" => DiskSize.B(partition.region.start * partition.region.block_size).to_s_ex,
          "name" => partition.name,
          "type" => @partition_types[partition.type],
          "id"   => @partition_ids[partition.id] || "0x#{partition.id.to_s(16)}"
        }

        begin
          file_system = partition.filesystem # This will raise an exception if there is no file system
          content["file_system"] = @file_system_types[file_system.type]
          content["mount_point"] = file_system.mountpoints.first unless file_system.mountpoints.empty?
          content["label"] = file_system.label unless file_system.label.empty?
        rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
          log.info("CAUGHT exception #{ex}")
        end

        { "partition" => content }
      end
      # rubocop:enable Metrics/AbcSize

      #
      # Return the YAML counterpart of a free slot between partitions on a
      # disk.
      #
      # @param  size [DiskSize] size of the free slot
      # @return [Hash]
      #
      def yaml_free_slot(start, size)
        { "free" => { "size" => size.to_s_ex, "start" => start.to_s_ex } }
      end
    end
  end
end
