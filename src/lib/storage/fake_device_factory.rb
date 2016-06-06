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
require "storage"
require "storage/patches"
require "storage/abstract_device_factory.rb"
require "storage/disk_size.rb"
require "storage/enum_mappings.rb"

module Yast
  module Storage
    #
    # Factory class to generate faked devices in a device graph.
    # This is typically used with a YAML file.
    # Use the inherited load_yaml_file() to start the process.
    #
    class FakeDeviceFactory < AbstractDeviceFactory
      include EnumMappings

      # Valid toplevel products of this factory
      VALID_TOPLEVEL  = ["disk"]

      # Valid hierarchy within the products of this factory.
      # This indicates the permitted children types for each parent.
      VALID_HIERARCHY =
        {
          "disk"       => ["partition_table", "partitions", "file_system"],
          "partitions" => ["partition", "free"],
          "partition"  => ["file_system"]
        }

      # Valid parameters for each product of this factory.
      # Sub-products are not listed here.
      VALID_PARAM =
        {
          "disk"            => ["name", "size", "block_size", "io_size", "min_grain", "align_ofs", "mbr_gap"],
          "partition_table" => [],
          "partitions"      => [],
          "partition"       => ["size", "start", "name", "type", "id", "mount_point", "label", "uuid"],
          "file_system"     => [],
          "free"            => ["size","start"]
        }

      class << self
        #
        # Read a YAML file and build a fake device tree from it.
        #
        # This is a singleton method for convenience. It creates a
        # FakeDeviceFactory internally for one-time usage. If you use this more
        # often (for example, in a loop), it is recommended to use create a
        # FakeDeviceFactory and use its load_yaml_file() method repeatedly.
        #
        # @param devicegraph [::Storage::Devicegraph] where to build the tree
        # @param input_file [String] name of the YAML file
        #
        def load_yaml_file(devicegraph, input_file)
          factory = FakeDeviceFactory.new(devicegraph)
          factory.load_yaml_file(input_file)
        end
      end

      def initialize(devicegraph)
        super(devicegraph)
        @partitions     = {}
        @disks          = Set.new
        @disk_size      = {}
        @disk_used      = {}
        @free_blob      = nil
        @mbr_gap        = nil
      end

    protected

      # Return a hash for the valid hierarchy of the products of this factory:
      # Each hash key returns an array (that might be empty) for the child
      # types that are valid below that key.
      #
      # @return [Hash<String, Array<String>>]
      #
      def valid_hierarchy
        VALID_HIERARCHY
      end

      # Return an array for valid toplevel products of this factory.
      #
      # @return [Array<String>] valid toplevel products
      #
      def valid_toplevel
        VALID_TOPLEVEL
      end

      # Return an hash of valid parameters for each product type of this
      # factory. This does not include sub-products, only the parameters that
      # are passed directly to each individual product.
      #
      # @return [Hash<String, Array<String> >]
      #
      def valid_param
        VALID_PARAM
      end

      # Fix up parameters to the create_xy() methods.  In this instance,
      # this is used to convert parameters representing a DiskSize to a
      # DiskSize object that can be used directly.
      #
      # This method is optional. The base class checks with respond_to? if it
      # is implemented before it is called.
      #
      # @param name [String] factory product name
      # @param param [Hash] create_xy() parameters
      #
      # @return [Hash or Scalar] changed parameters
      #
      def fixup_param(name, param)
        log.info("Fixing up #{param} for #{name}")
        ["size", "start", "block_size", "io_size", "min_grain", "align_ofs", "mbr_gap"].each do |key|
          param[key] = DiskSize.new(param[key]) if param.key?(key)
        end
        param
      end

      #
      # Factory methods
      #
      # The AbstractDeviceFactory base class will collect all methods starting
      # with "create_" via Ruby introspection (methods()) and use them for
      # creating factory products.
      #

      # Factory method to create a disk.
      #
      # @param _parent [nil] (disks are toplevel)
      # @param args [Hash] disk parameters: "name", "size", "range"
      #
      # @return [String] device name of the new disk ("/dev/sda" etc.)
      #
      def create_disk(_parent, args)
        log.info("#{__method__}( #{args} )")
        name = args["name"] || "/dev/sda"
        size = args["size"] || DiskSize.zero
        raise ArgumentError, "\"size\" missing for disk #{name}" if size.zero?
        raise ArgumentError, "Duplicate disk name #{name}" if @disks.include?(name)
        @disks << name
        block_size = args["block_size"] if args["block_size"]
        io_size = args["io_size"] if args["io_size"]
        min_grain = args["min_grain"] if args["min_grain"]
        align_ofs = args["align_ofs"] if args["align_ofs"]
        if args["mbr_gap"]
          @mbr_gap = args["mbr_gap"]
        else
          @mbr_gap = nil
        end
        if block_size && block_size.size > 0
          r = ::Storage::Region.new(0, size.size / block_size.size, block_size.size)
          disk = ::Storage::Disk.create(@devicegraph, name, r)
        else
          disk = ::Storage::Disk.create(@devicegraph, name)
          disk.size = size.size
        end
        if io_size && io_size.size > 0
          disk.topology.optimal_io_size = io_size.size
        end
        if align_ofs
          disk.topology.alignment_offset = align_ofs.size
        end
        if min_grain && min_grain.size > 0
          disk.topology.minimal_grain = min_grain.size
        end
        # range (number of partitions that the kernel can handle) used to be
        # 16 for scsi and 64 for ide. Now it's 256 for most of them.
        disk.range = args["range"] || 256
        @disk_used[name] = 0
        @disk_size[name] = disk.size
        name
      end

      # Factory method to create a partition table.
      #
      # @param parent [String] disk name ("/dev/sda" etc.)
      # @param args [String] disk label type: "gpt", "ms-dos"
      #
      # @return [String] device name of the disk ("/dev/sda" etc.)
      #
      def create_partition_table(parent, args)
        log.info("#{__method__}( #{parent}, #{args} )")
        disk_name = parent
        ptable_type = str_to_ptable_type(args)
        disk = ::Storage::Disk.find_by_name(@devicegraph, disk_name)
        ptable = disk.create_partition_table(ptable_type)
        if ::Storage.msdos?(ptable) && @mbr_gap
          ::Storage.to_msdos(ptable).minimal_mbr_gap = @mbr_gap.size;
        end
        disk_name
      end

      # Partition table type represented by a string
      #
      # @param string [String] usually from a YAML file
      # @return [Fixnum]
      def str_to_ptable_type(string)
        # Allow different spelling
        string = "msdos" if string.downcase == "ms-dos"
        fetch(PARTITION_TABLE_TYPES, string, "partition table type", "disk_name")
      end

      # Factory method to create a partition.
      #
      # Some of the parameters ("mount_point", "label"...) really belong to the
      # file system which is a separate factory product, but it is more natural
      # to specify this for the partition, so those data are kept in
      # @partitions to be picked up in create_file_system when needed.
      #
      # @param parent [String] disk name ("/dev/sda" etc.)
      #
      # @param args [Hash] partition table parameters:
      #   "size"  partition size
      #   "name"  device name ("/dev/sdb3" etc.)
      #   "type"  "primary", "extended", "logical"
      #   "id"
      #   "mount_point"  mount point for the associated file system
      #   "label"        file system label
      #   "uuid"         file system UUID
      #
      # @return [String] device name of the disk ("/dev/sda" etc.)
      #
      # FIXME: this method is too complex. It offends three different cops
      # related to complexity.
      # rubocop:disable Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/CyclomaticComplexity
      def create_partition(parent, args)
        log.info("#{__method__}( #{parent}, #{args} )")
        disk_name = parent
        size      = args["size"] || DiskSize.unlimited
        start     = args["start"]
        part_name = args["name"]
        type      = args["type"] || "primary"
        id        = args["id"] || "linux"

        raise ArgumentError, "\"name\" missing for partition #{args} on #{disk_name}" unless part_name
        raise ArgumentError, "\"size\" missing for partition #{part_name}" if size.zero?
        raise ArgumentError, "Duplicate partition #{part_name}" if @partitions.include?(part_name)

        # Keep some parameters that are really file system related in @partitions
        # to be picked up later by create_file_system.
        @partitions[part_name] = args.select do |k, _v|
          ["mount_point", "label", "uuid"].include?(k)
        end

        id = id.to_i(16) if id.is_a?(::String) && id.start_with?("0x")
        id   = fetch(PARTITION_IDS,   id,   "partition ID",   part_name) unless id.is_a?(Fixnum)
        type = fetch(PARTITION_TYPES, type, "partition type", part_name)

        disk = ::Storage::Disk.find_by_name(devicegraph, disk_name)
        ptable = disk.partition_table
        slots = ptable.unused_partition_slots
        # partitions are created in order, so first slot should be fine
        # FIXME: we need to do better than this!
        region = slots.first.region
        # if no start has been specified, take free region into account
        if !start && @free_blob
          start_block = region.start + @free_blob.size / region.block_size
        end
        @free_blob = nil
        # if start has been specified, use it
        if start
          start_block = start.size / region.block_size
        end
        # adjust start block, if necessary
        if start_block
          if start_block > region.start && start_block <= region.end
            region.adjust_length(region.start - start_block)
          end
          region.start = start_block
        end
        # if no size has been specified, use whole region
        if !size.unlimited?
          region.length = size.size / region.block_size
        end
        #@disk_used[disk_name] = (region.start + 1) * region.block_size if type == ::Storage::PartitionType_EXTENDED
        partition = ptable.create_partition(part_name, region, type)
        partition.id = id
        part_name
      end
      # rubocop:enable all

      # Factory method to create a file system.
      #
      # This fetches some parameters from @partitions: "mount_point", "label".
      #
      # @param parent [String] partition device name ("/dev/sdc2")
      # @param args   [String] file system type ("xfs", "btrfs", ...)
      #
      # @return [String] partition device name ("/dev/sdc2" etc.)
      #
      def create_file_system(parent, args)
        log.info("#{__method__}( #{parent}, #{args} )")
        part_name = parent
        fs_type = fetch(FILE_SYSTEM_TYPES, args, "file system type", part_name)

        # Fetch file system related parameters stored by create_partition()
        fs_param = @partitions[part_name] || {}
        mount_point = fs_param["mount_point"]
        label       = fs_param["label"]
        uuid        = fs_param["uuid"]

        partition = ::Storage::Partition.find_by_name(@devicegraph, part_name)
        file_system = partition.create_filesystem(fs_type)
        file_system.add_mountpoint(mount_point) if mount_point
        file_system.label = label if label
        file_system.uuid = uuid if uuid
        part_name
      end

      # Factory method to create a slot of free space.
      #
      # @param parent [String] disk name ("/dev/sda" etc.)
      #
      # @param args [Hash] free space parameters:
      #   "size"  free space size
      #
      # @return [String] device name of the disk ("/dev/sda" etc.)
      #
      def create_free(parent, args)
        log.info("#{__method__}( #{parent}, #{args} )")
        disk_name = parent
        @free_blob = args["size"] if args["size"]
        disk_name
      end

    private

      # Fetch hash[key] and raise an exception if there is no such key.
      #
      # @param hash [Hash]   hash to search in
      # @param key  [String] key  in the hash to access
      # @param type [String] type (description) of 'key'
      # @param name [String] name of the object that 'hash' belongs to
      #
      def fetch(hash, key, type, name)
        value = hash[key.downcase]
        if !value
          raise ArgumentError, "Invalid #{type} \"#{key}\" for #{name} - use one of #{hash.keys}"
        end
        value
      end
    end
  end
end
