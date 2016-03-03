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
        # @param yaml_file_name [String]
        #
        def write(devicegraph, yaml_file_name)
          writer = YamlWriter.new
          writer.write(devicegraph, yaml_file_name)
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
      # @param yaml_file_name [String]
      #
      def write(devicegraph, yaml_file_name)
        device_tree = yaml_device_tree(devicegraph)
        File.open(yaml_file_name, "w") { |file| file.write(device_tree.to_yaml) }
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
        content["size"] = DiskSize.new(disk.size_k).to_s
        content["name"] = disk.name
        begin
          ptable = disk.partition_table # this will raise an excepton if no partition table
          content["partition_table"] = @partition_table_types[ptable.type]
          cyl_size = DiskSize.new(disk.geometry.cylinder_size / 1024)
          first_free_cyl = 0
          partitions = []

          ptable.partitions.each do |partition|
            gap = partition.region.start - first_free_cyl
            if gap > 0
              partitions << yaml_free_slot(cyl_size * gap)
            end

            partitions << yaml_partition(partition)
            first_free_cyl = partition.region.end + 1 unless partition.type == ::Storage::PartitionType_EXTENDED
          end
          content["partitions"] = partitions unless partitions.empty?
        rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
          log.info("CAUGHT exception #{ex}")
        end

        { "disk" => content }
      end

      #
      # Return the YAML counterpart of a ::Storage::Partition.
      #
      # @param  partition [::Storage::Partition]
      # @return [Hash]
      #
      def yaml_partition(partition)
        content = {}
        content["size"] = DiskSize.new(partition.region.to_kb(partition.region.length)).to_s
        content["name"] = partition.name
        content["type"] = @partition_types[partition.type]
        content["id"] = @partition_ids[partition.id]

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

      #
      # Return the YAML counterpart of a free slot between partitions on a
      # disk.
      #
      # @param  size [DiskSize] size of the free slot
      # @return [Hash]
      #
      def yaml_free_slot(size)
        { "free" => { "size" => size.to_s } }
      end
    end
  end
end
