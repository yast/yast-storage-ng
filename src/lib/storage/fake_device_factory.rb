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
require "pp"

module Yast
  module Storage
    #
    # Factory class to generate faked devices in a device graph.
    # This is typically used with a YaML file.
    # Use the inherited load_yaml_file() to start the process.
    #
    class FakeDeviceFactory < AbstractDeviceFactory

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


      # Valid values (case insensitive) and mapping for partition_table types.
      PARTITION_TABLE_TYPES =
        {
          "loop"   => ::Storage::PtType_PT_LOOP,
          "msdos"  => ::Storage::PtType_MSDOS,
          "ms-dos" => ::Storage::PtType_MSDOS,
          "gpt"    => ::Storage::PtType_GPT,
          "dasd"   => ::Storage::PtType_DASD,
          "mac"    => ::Storage::PtType_MAC
        }

      # Valid values (case insensitive) and mapping for partition  types.
      PARTITION_TYPES =
        {
          "primary"  => ::Storage::PRIMARY,
          "extended" => ::Storage::EXTENDED,
          "logical"  => ::Storage::LOGICAL
        }

      # Valid values (case insensitive) and mapping for partition IDs.
      # The corresponding hex numbers can also be used.
      PARTITION_IDS =
        {
          "dos12"       => ::Storage::ID_DOS12,       #  0x01
          "dos16"       => ::Storage::ID_DOS16,       #  0x06
          "dos32"       => ::Storage::ID_DOS32,       #  0x0c
          "ntfs"        => ::Storage::ID_NTFS,        #  0x07
          "extended"    => ::Storage::ID_EXTENDED,    #  0x0f
          "ppc_prep"    => ::Storage::ID_PPC_PREP,    #  0x41
          "linux"       => ::Storage::ID_LINUX,       #  0x83
          "swap"        => ::Storage::ID_SWAP,        #  0x82
          "lvm"         => ::Storage::ID_LVM,         #  0x8e
          "raid"        => ::Storage::ID_RAID,        #  0xfd
          "apple_other" => ::Storage::ID_APPLE_OTHER, #  0x101
          "apple_hfs"   => ::Storage::ID_APPLE_HFS,   #  0x102
          "gpt_boot"    => ::Storage::ID_GPT_BOOT,    #  0x103
          "gpt_service" => ::Storage::ID_GPT_SERVICE, #  0x104
          "gpt_msftres" => ::Storage::ID_GPT_MSFTRES, #  0x105
          "apple_ufs"   => ::Storage::ID_APPLE_UFS,   #  0x106
          "gpt_bios"    => ::Storage::ID_GPT_BIOS,    #  0x107
          "gpt_prep"    => ::Storage::ID_GPT_PREP     #  0x108
        }

      # Valid values (case insensitive) and mapping for file system types.
      FILE_SYSTEM_TYPES =
        {
          "reiserfs" => ::Storage::REISERFS,
          "ext2"     => ::Storage::EXT2,
          "ext3"     => ::Storage::EXT3,
          "ext4"     => ::Storage::EXT4,
          "btrfs"    => ::Storage::BTRFS,
          "vfat"     => ::Storage::VFAT,
          "xfs"      => ::Storage::XFS,
          "jfs"      => ::Storage::JFS,
          "hfs"      => ::Storage::HFS,
          "ntfs"     => ::Storage::NTFS,
          "swap"     => ::Storage::SWAP,
          "hfsplus"  => ::Storage::HFSPLUS,
          "nfs"      => ::Storage::NFS,
          "nfs4"     => ::Storage::NFS4,
          "tmpfs"    => ::Storage::TMPFS,
          "iso9660"  => ::Storage::ISO9660,
          "udf"      => ::Storage::UDF
        }

      def initialize(devicegraph)
        super(devicegraph)
        @partitions = Hash.new
        @disks      = Set.new
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
        region = unused_region(disk_name, size)
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

        # TO DO
        # TO DO
        # TO DO

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
        raise ArgumentError, "Invalid #{type} #{key} for #{name} - use one of #{hash.keys}" unless value
        value
      end

      # Find a region of unused disk space on disk 'disk_name'. If 'size' is
      # 'unlimited', the remaining free space of the disk is taken
      # completely. This is most useful for an extended partition or in general
      # for the last partition on a disk.
      #
      # @param disk_name [String] device name of the disk ("/dev/sdc" etc.)
      # @param size [DiskSize] desired size of the region
      #
      # @return [::Storage::Region]
      #
      def unused_region(disk_name, size)
        disk = ::Storage::Disk.find(@devicegraph, disk_name)
        region_start = -1
        block_size   = -1
        blocks       = -1

        log.info("#{__method__}: #{disk.partition_table.unused_partition_slots.size} slots on #{disk_name}")
        disk.partition_table.unused_partition_slots.each do |slot|
          log.info("Free slot on #{disk_name}")
          block_size = slot.region.block_size
          if size.unlimited?
            region_start = slot.region.start
            blocks = slot.region.length
            break
          else
            requested_blocks = (1024 * size.size_k) / block_size

            if requested_blocks <= slot.region.length
              region_start = slot.region.start
              blocks = requested_blocks
              break
            else
              log.info("Found region with #{slot.region.length} blocks (too small) on #{disk_name}")
            end
          end
        end
        raise RuntimeError, "Not enough disk space on #{disk_name} for another #{size}" if region_start < 0
        log.info("Found #{blocks} blocks on #{disk_name}")
        # region.dup doesn't seem to work (SWIG bindings problem?)
        ::Storage::Region.new(region_start, blocks, block_size)
      end

      # Return a fake disk geometry with a given size.
      #
      # @param size [DiskSize]
      # @return [::Storage::Geometry] Geometry with that size
      #
      def fake_geometry(size)
        sector_size = 512
        blocks  = (size.size_k * 1024) / sector_size
        heads   = 16  # 1 MiB cylinders (16 * 128 * 512 Bytes)
        sectors = 128
        cyl     = blocks / (heads * sectors)
        # log.info("Geometry: #{cyl} cyl #{heads} heads #{sectors} sectors = #{size}")
        ::Storage::Geometry.new(cyl, heads, sectors, sector_size)
      end
    end
  end
end
