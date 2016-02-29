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
      VALID_TOPLEVEL  = [ "disk" ]

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
          "disk"            => ["name", "size"],
          "partition_table" => [],
          "partitions"      => [],
          "partition"       => ["size", "name", "type", "id", "mount_point", "label"],
          "file_system"     => [],
          "free"            => ["size"]
        }

      # Size of a cylinder of our fake geometry disks
      CYL_SIZE = DiskSize.MiB(1)

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
        @partitions     = Hash.new
        @disks          = Set.new
        @first_free_cyl = Hash.new
        @cyl_count      = Hash.new
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

      # Fix up parameters to the create_xy() methods. In this instance, this is
      # used to convert any parameter called "size" to a DiskSize that can be
      # used directly.
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
        # log.info("Fixing up #{param} for #{name}")
        param["size"] = DiskSize::parse(param["size"]) if param.key?("size")
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
      # @param parent [nil] (disks are toplevel)
      # @param args [Hash] disk parameters: "name", "size"
      #
      # @return [String] device name of the new disk ("/dev/sda" etc.)
      #
      def create_disk(parent, args)
        log.info("#{__method__}( #{args} )")
        name = args["name"] || "/dev/sda"
        size = args["size"] || DiskSize.zero
        raise ArgumentError, "\"size\" missing for disk #{name}" if size.zero?
        raise ArgumentError, "Duplicate disk name #{name}" if @disks.include?(name)
        @disks << name
        disk = ::Storage::Disk.create(@devicegraph, name)
        disk.size_k = size.size_k
        disk.geometry = fake_geometry(size)
        @first_free_cyl[name] = 0
        @cyl_count[name] = disk.geometry.cylinders
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
        args = "msdos" if args.downcase == "ms-dos" # Allow different spelling
        ptable_type = fetch(PARTITION_TABLE_TYPES, args, "partition table type", "disk_name")
        disk = ::Storage::Disk.find(@devicegraph, disk_name)
        disk.create_partition_table(ptable_type)
        disk_name
      end

      # Factory method to create a partition.
      #
      # Some of the parameters ("mount_point", "label") really belong to the
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
      #
      # @return [String] device name of the disk ("/dev/sda" etc.)
      #
      def create_partition(parent, args)
        log.info("#{__method__}( #{parent}, #{args} )")
        disk_name = parent
        disk = ::Storage::Disk.find(@devicegraph, disk_name)
        size      = args["size"] || DiskSize.zero
        part_name = args["name"]
        type      = args["type"] || "primary"
        id        = args["id"  ] || "linux"

        raise ArgumentError, "\"name\" missing for partition #{args} on #{disk_name}" unless part_name
        raise ArgumentError, "\"size\" missing for partition #{part_name}" if size.zero?
        raise ArgumentError, "Duplicate partition #{part_name}" if @partitions.include?(part_name)

        # Keep some parameters that are really file system related in @partitions
        # to be picked up later by create_file_system.
        @partitions[part_name] = args.select { |k,v| ["mount_point", "label"].include?(k) }

        id   = fetch(PARTITION_IDS,   id,   "partition ID",   part_name) unless id.is_a?(Fixnum)
        type = fetch(PARTITION_TYPES, type, "partition type", part_name)

        disk = ::Storage::Disk.find(devicegraph, disk_name)
        ptable = disk.partition_table
        region = allocate_disk_space(disk_name, size)
        @first_free_cyl[disk_name] = region.start if type == ::Storage::PartitionType_EXTENDED
        partition = ptable.create_partition(part_name, region, type)
        partition.id = id
        part_name
      end

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

        partition = ::Storage::Partition.find(@devicegraph, part_name)
        file_system = partition.create_filesystem(fs_type)
        file_system.add_mountpoint(mount_point) if mount_point
        file_system.label = label if label
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
        size = args["size"] || DiskSize.zero
        raise ArgumentError, "Invalid size of free space on #{disk_name}" if size.zero?
        allocate_disk_space(disk_name, size)
        log.info("Allocated #{size} free space on #{disk_name}")
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
        raise ArgumentError, "Invalid #{type} \"#{key}\" for #{name} - use one of #{hash.keys}" unless value
        value
      end

      # Allocate disk space of size 'size' on disk 'disk_name'. If 'size' is
      # 'unlimited', consume all the the remaining free space of the disk.
      #
      # This uses and sets @first_free_cyl[name] according to the amount of
      # space allocated. For extended partitions, this may have to be corrected
      # later to make room for the logical partitions inside the extended
      # partition.
      #
      # @param disk_name [String] device name of the disk ("/dev/sdc" etc.)
      # @param size [DiskSize] desired size of the region
      #
      # @return [::Storage::Region]
      #
      def allocate_disk_space(disk_name, size)
        disk = ::Storage::Disk.find(@devicegraph, disk_name)
        log.info("#{__method__}: #{disk.partition_table.unused_partition_slots.size} slots on #{disk_name}")

        first_free_cyl = @first_free_cyl[disk_name] || 0
        cyl_count      = @cyl_count[disk_name] || 0
        free_cyl = cyl_count - first_free_cyl
        log.info("disk #{disk_name} first free cyl: #{first_free_cyl} free_cyl: #{free_cyl} cyl_count: #{cyl_count}")

        if size.unlimited?
          requested_cyl = free_cyl
          raise RuntimeError, "No more disk space on #{disk_name}" if requested_cyl < 1
        else
          requested_cyl = size.size_k / CYL_SIZE.size_k
          raise RuntimeError, "Not enough disk space on #{disk_name} for another #{size}" if requested_cyl > free_cyl
        end
        @first_free_cyl[disk_name] = first_free_cyl + requested_cyl
        ::Storage::Region.new(first_free_cyl, requested_cyl, CYL_SIZE.size_k * 1024)
      end

      # Return a fake disk geometry with a given size.
      #
      # @param size [DiskSize]
      # @return [::Storage::Geometry] Geometry with that size
      #
      def fake_geometry(size)
        sector_size = 512
        blocks  = (size.size_k * 1024) / sector_size
        heads   = 16  # 1 MiB cylinders (16 * 128 * 512 Bytes) - see also CYL_SIZE
        sectors = 128
        cyl     = blocks / (heads * sectors)
        # log.info("Geometry: #{cyl} cyl #{heads} heads #{sectors} sectors = #{size}")
        ::Storage::Geometry.new(cyl, heads, sectors, sector_size)
      end
    end
  end
end
