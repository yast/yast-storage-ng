#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2017] SUSE LLC
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
require "y2storage"
require "y2storage/abstract_device_factory"

module Y2Storage
  #
  # Factory class to generate faked devices in a device graph.
  # This is typically used with a YAML file.
  # Use the inherited load_yaml_file() to start the process.
  #
  # rubocop:disable Metrics/ClassLength
  #
  class FakeDeviceFactory < AbstractDeviceFactory
    # Valid toplevel products of this factory
    VALID_TOPLEVEL  = ["dasd", "disk", "lvm_vg"]

    # Valid hierarchy within the products of this factory.
    # This indicates the permitted children types for each parent.
    VALID_HIERARCHY =
      {
        "dasd"       => ["partition_table", "partitions", "file_system", "encryption"],
        "disk"       => ["partition_table", "partitions", "file_system", "encryption"],
        "partitions" => ["partition", "free"],
        "partition"  => ["file_system", "encryption", "btrfs"],
        "encryption" => ["file_system"],
        "lvm_vg"     => ["lvm_lvs", "lvm_pvs"],
        "lvm_lvs"    => ["lvm_lv"],
        "lvm_lv"     => ["file_system", "encryption", "btrfs"],
        "lvm_pvs"    => ["lvm_pv"],
        "lvm_pv"     => [],
        "btrfs"      => ["subvolumes"],
        "subvolumes" => ["subvolume"]
      }

    # Valid parameters for file_system
    FILE_SYSTEM_PARAM = [
      "mount_point", "label", "uuid", "fstab_options", "btrfs", "mount_by", "mkfs_options"
    ]

    # Valid parameters for each product of this factory.
    # Sub-products are not listed here.
    VALID_PARAM =
      {
        "dasd"            => [
          "name", "size", "block_size", "io_size", "min_grain", "align_ofs", "type", "format"
        ].concat(FILE_SYSTEM_PARAM),
        "disk"            => [
          "name", "size", "block_size", "io_size", "min_grain", "align_ofs", "mbr_gap"
        ].concat(FILE_SYSTEM_PARAM),
        "partition_table" => [],
        "partitions"      => [],
        "partition"       => [
          "size", "start", "align", "name", "type", "id"
        ].concat(FILE_SYSTEM_PARAM),
        "file_system"     => [],
        "encryption"      => ["name", "type", "password"],
        "free"            => ["size", "start"],
        "lvm_vg"          => ["vg_name", "extent_size"],
        "lvm_lv"          => [
          "lv_name", "size", "stripes", "stripe_size"
        ].concat(FILE_SYSTEM_PARAM),
        "lvm_pv"          => ["blk_device"],
        "btrfs"           => ["default_subvolume"],
        "subvolumes"      => [],
        "subvolume"       => ["path", "nocow"]
      }

    # Dependencies between products on the same hierarchy level.
    DEPENDENCIES =
      {
        # file_system depends on encryption because any encryption needs to be
        # created first (and then the file system on the encryption layer).
        #
        # file_system depends on partition_table so a partition table is
        # created before any file_system directly on a disk so an error can be
        # reported if both are specified: It's either a partiton table or a
        # file system, not both.
        #
        "file_system" => ["encryption", "partition_table"]
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
      # @param devicegraph [Devicegraph] where to build the tree
      # @param input_file [String] name of the YAML file
      #
      def load_yaml_file(devicegraph, input_file)
        factory = FakeDeviceFactory.new(devicegraph)
        factory.load_yaml_file(input_file)
      end
    end

    def initialize(devicegraph)
      super(devicegraph)
      @disks = Set.new
      @file_system_data = {}
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
      ["size", "start", "block_size", "io_size", "min_grain", "align_ofs",
       "mbr_gap", "extent_size", "stripe_size"].each do |key|
        param[key] = DiskSize.new(param[key]) if param.key?(key)
      end
      param
    end

    # Return a hash describing dependencies from one sub-product (on the same
    # hierarchy level) to another so they can be produced in the correct order.
    #
    # For example, if there is an encryption layer and a file system in a
    # partition, the encryption layer needs to be created first so the file
    # system can be created inside that encryption layer.
    #
    def dependencies
      DEPENDENCIES
    end

    #
    # Factory methods
    #
    # The AbstractDeviceFactory base class will collect all methods starting
    # with "create_" via Ruby introspection (methods()) and use them for
    # creating factory products.
    #

    # Factory method to create a DASD disk.
    #
    # @param _parent [nil] (disks are toplevel)
    # @param args [Hash] disk parameters:
    #   "name"       device name ("/dev/sda" etc.)
    #   "size"       disk size
    #   "block_size" block size
    #   "io_size"    optimal io size
    #   "min_grain"  minimal grain
    #   "align_ofs"  alignment offset
    #   "type"       DASD type ("eckd", "fba")
    #   "format"     DASD format ("ldl", "cdl")
    #
    # @return [String] device name of the new DASD disk ("/dev/sda" etc.)
    def create_dasd(_parent, args)
      dasd_args = add_defaults_for_dasd(args)
      dasd = new_partitionable(Dasd, dasd_args)
      type = fetch(DasdType, dasd_args["type"], "dasd type", dasd_args["name"])
      format = fetch(DasdFormat, dasd_args["format"], "dasd format", dasd_args["name"])
      dasd.type = type unless type.is?(:unknown)
      dasd.format = format unless format.is?(:none)
      dasd.name
    end

    def add_defaults_for_dasd(args)
      dasd_args = args.dup
      dasd_args["name"] ||= "/dev/dasda"
      dasd_args["type"] ||= "unknown"
      dasd_args["format"] ||= "none"
      if dasd_args["type"] == "eckd"
        dasd_args["block_size"] ||= DiskSize.KiB(4)
        dasd_args["min_grain"] ||= DiskSize.KiB(4)
      end
      dasd_args
    end

    # Factory method to create a disk.
    #
    # @param _parent [nil] (disks are toplevel)
    # @param args [Hash] disk parameters:
    #   "name"       device name ("/dev/sda" etc.)
    #   "size"       disk size
    #   "range"      max number of partitions
    #   "block_size" block size
    #   "io_size"    optimal io size
    #   "min_grain"  minimal grain
    #   "align_ofs"  alignment offset
    #   "mbr_gap"    mbr gap (for msdos partition table)
    #
    # @return [String] device name of the new disk ("/dev/sda" etc.)
    def create_disk(_parent, args)
      new_partitionable(Disk, args).name
    end

    # Method to create a partitionable.
    # @see #create_dasd
    # @see #create_disk
    #
    # @param partitionable_class [Dasd, Disk]
    # @param args [Hash<String, String>]
    #
    # @return [Y2Storage::Partitionable] device
    #
    # FIXME: this method is too complex. It offends three different cops
    # related to complexity.
    # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize
    def new_partitionable(partitionable_class, args)
      @volumes = Set.new
      @free_blob      = nil
      @free_regions   = []
      @mbr_gap        = nil

      log.info("#{__method__}( #{args} )")
      name = args["name"] || "/dev/sda"
      size = args["size"] || DiskSize.zero
      raise ArgumentError, "\"size\" missing for disk #{name}" if size.zero?
      raise ArgumentError, "Duplicate disk name #{name}" if @disks.include?(name)
      @disks << name
      block_size = args["block_size"] if args["block_size"]
      @mbr_gap = args["mbr_gap"] if args["mbr_gap"]
      if block_size && block_size.size > 0
        r = Region.create(0, size.to_i / block_size.to_i, block_size)
        disk = partitionable_class.create(@devicegraph, name, r)
      else
        disk = partitionable_class.create(@devicegraph, name)
        disk.size = size
      end
      set_topology_attributes!(disk, args)
      # range (number of partitions that the kernel can handle) used to be
      # 16 for scsi and 64 for ide. Now it's 256 for most of them.
      disk.range = args["range"] || 256
      file_system_directly_on_disk(disk, args) if args.keys.any? { |x| FILE_SYSTEM_PARAM.include?(x) }
      disk
    end
    # rubocop:enable all

    # Create a filesystem directly on a disk.
    #
    # @param disk [Disk]
    # @param args [Hash] disk and filesystem parameters
    def file_system_directly_on_disk(disk, args)
      # No use trying to check for disk.has_partition_table here and throwing
      # an error in that case: The AbstractDeviceFactory base class will
      # already have caused a Storage::WrongNumberOfChildren exception and
      # convert that into a better readable HierarchyError. When we get here,
      # that error already happened.
      log.info("Creating filesystem directly on disk #{args}")
      file_system_data_picker(disk.name, args)
    end

    # Modifies topology settings of the disk according to factory arguments
    #
    # @param disk [Disk]
    # @param args [Hash] disk parameters. See {#create_disk}
    def set_topology_attributes!(disk, args)
      io_size = args["io_size"]
      min_grain = args["min_grain"]
      align_ofs = args["align_ofs"]
      disk.topology.optimal_io_size = io_size.size if io_size && io_size.size > 0
      disk.topology.alignment_offset = align_ofs.size if align_ofs
      disk.topology.minimal_grain = min_grain.size if min_grain && min_grain.size > 0
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
      disk = Partitionable.find_by_name(@devicegraph, disk_name)
      ptable = disk.create_partition_table(ptable_type)
      if ptable.respond_to?(:minimal_mbr_gap=) && @mbr_gap
        ptable.minimal_mbr_gap = @mbr_gap
      end
      disk_name
    end

    # Partition table type represented by a string
    #
    # @param string [String] usually from a YAML file
    # @return [PartitionTables::Type]
    def str_to_ptable_type(string)
      # Allow different spelling
      string = "msdos" if string.casecmp("ms-dos").zero?
      fetch(PartitionTables::Type, string, "partition table type", "disk_name")
    end

    # Factory method to create a partition.
    #
    # Some of the parameters ("mount_point", "label"...) really belong to the
    # file system which is a separate factory product, but it is more natural
    # to specify this for the partition, so those data are kept
    # in @file_system_data to be picked up in create_file_system when needed.
    #
    # @param parent [String] disk name ("/dev/sda" etc.)
    #
    # @param args [Hash] partition table parameters:
    #   "size"  partition size (unlimited if missing)
    #   "start" partition start (optional)
    #   "align" partition align policy (optional)
    #   "name"  device name ("/dev/sdb3" etc.)
    #   "type"  "primary", "extended", "logical"
    #   "id"
    #   "mount_point"   mount point for the associated file system
    #   "label"         file system label
    #   "uuid"          file system UUID
    #   "fstab_options" /etc/fstab options for the file system
    #
    # @return [String] device name of the disk ("/dev/sda" etc.)
    #
    # FIXME: this method is too complex. It offends four different cops
    # related to complexity.
    # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    # rubocop:disable  Metrics/MethodLength, Metrics/AbcSize
    def create_partition(parent, args)
      log.info("#{__method__}( #{parent}, #{args} )")
      disk_name = parent
      size      = args["size"] || DiskSize.unlimited
      start     = args["start"]
      part_name = args["name"]
      type      = args["type"] || "primary"
      id        = args["id"] || "linux"
      align     = args["align"]

      raise ArgumentError, "\"name\" missing for partition #{args} on #{disk_name}" unless part_name
      raise ArgumentError, "Duplicate partition #{part_name}" if @volumes.include?(part_name)

      @volumes << part_name
      file_system_data_picker(part_name, args)

      id = id.to_i(16) if id.is_a?(::String) && id.start_with?("0x")
      id   = fetch(PartitionId,   id,   "partition ID",   part_name) unless id.is_a?(Integer)
      type = fetch(PartitionType, type, "partition type", part_name)
      align = fetch(AlignPolicy,  align, "align policy",  part_name) if align

      disk = Partitionable.find_by_name(devicegraph, disk_name)
      ptable = disk.partition_table
      slots = ptable.unused_partition_slots

      # partitions are created in order, so first suitable slot should be fine
      # note: skip areas we marked as empty
      slot = slots.find { |s| s.possible?(type) && !@free_regions.member?(s.region.start) }
      raise ArgumentError, "No suitable slot for partition #{part_name}" if !slot
      region = slot.region

      # region = slots.first.region
      # if no start has been specified, take free region into account
      if !start && @free_blob
        @free_regions.push(region.start)
        start_block = region.start + @free_blob.to_i / region.block_size.to_i
      end
      @free_blob = nil

      # if start has been specified, use it
      start_block = start.to_i / region.block_size.to_i if start

      # adjust start block, if necessary
      if start_block
        if start_block > region.start && start_block <= region.end
          region.adjust_length(region.start - start_block)
        end
        region.start = start_block
      end

      # if no size has been specified, use whole region
      if !size.unlimited?
        region.length = size.to_i / region.block_size.to_i
      end

      # align partition if specified
      region = disk.topology.align(region, align) if align

      partition = ptable.create_partition(part_name, region, type)
      partition.id = id

      part_name
    end
    # rubocop:enable all

    # Factory method to create a file system.
    #
    # This fetches some parameters from @file_system_data:
    # "mount_point", "label", "uuid", "encryption"
    #
    # @param parent [String] parent (partition or disk) device name ("/dev/sdc2")
    # @param args   [String] file system type ("xfs", "btrfs", ...)
    #
    # @return [String] partition device name ("/dev/sdc2" etc.)
    #
    def create_file_system(parent, args)
      log.info("#{__method__}( #{parent}, #{args} )")
      fs_type = fetch(Filesystems::Type, args, "file system type", parent)

      # Fetch file system related parameters stored by create_partition()
      fs_param = @file_system_data[parent] || {}
      encryption = fs_param["encryption"]

      if !encryption.nil?
        log.info("file system is on encrypted device #{encryption}")
        parent = encryption
      end
      blk_device = BlkDevice.find_by_name(@devicegraph, parent)
      file_system = blk_device.create_blk_filesystem(fs_type)
      assign_file_system_params(file_system, fs_param)
      parent
    end

    def assign_file_system_params(file_system, fs_param)
      ["mount_point", "label", "uuid", "fstab_options", "mkfs_options"].each do |param|
        value = fs_param[param]
        file_system.public_send(:"#{param}=", value) if value
      end

      if fs_param["mount_by"]
        file_system.mount_by = fetch(
          Filesystems::MountByType, fs_param["mount_by"], "mount by name schema", file_system
        )
      end
    end

    # Picks some parameters that are really file system related from args
    # and places them in @file_system_data to be picked up later by
    # create_file_system.
    #
    # @param [String] name of blk_device file system is on
    #
    # @param args [Hash] hash with data from yaml file
    #
    def file_system_data_picker(name, args)
      fs_param = FILE_SYSTEM_PARAM << "encryption"
      @file_system_data[name] = args.select { |k, _v| fs_param.include?(k) }
    end

    # Factory method to create a slot of free space.
    #
    # We just remember the value and take it into account when we create the next partition.
    #
    # @param parent [String] disk name ("/dev/sda" etc.)
    #
    # @param args [Hash] free space parameters:
    #   "size"  free space size
    #   "start" (ignored)
    #
    # @return [String] device name of the disk ("/dev/sda" etc.)
    #
    def create_free(parent, args)
      log.info("#{__method__}( #{parent}, #{args} )")
      disk_name = parent
      size = args["size"]
      @free_blob = size if size && size.to_i > 0
      disk_name
    end

    # Factory method to create an encryption layer.
    #
    # @param parent [String] parent device name ("/dev/sda1" etc.)
    #
    # @param args [Hash] encryption layer parameters:
    #   "name"     name encryption layer ("/dev/mapper/cr_Something")
    #   "type"     encryption type; default: "luks"
    #   "password" encryption password (optional)
    #
    # @return [Object] new encryption object
    #
    def create_encryption(parent, args)
      log.info("#{__method__}( #{parent}, #{args} )")
      name = encryption_name(args["name"], parent)
      password = args["password"]
      type_name = args["type"] || "luks"
      # We only support creating LUKS so far
      raise ArgumentError, "Unsupported encryption type #{type_name}" unless type_name == "luks"

      blk_parent = BlkDevice.find_by_name(@devicegraph, parent)
      encryption = blk_parent.create_encryption(name)
      encryption.password = password unless password.nil?
      if @file_system_data.key?(parent)
        # Notify create_file_system that this partition is encrypted
        @file_system_data[parent]["encryption"] = encryption.name
      end
      encryption
    end

    def encryption_name(name, parent)
      result = nil

      if name.include?("/")
        if name.start_with?("/dev/mapper/")
          result = name.split("/").last
        else
          raise ArgumentError, "Unexpected \"name\" value for encryption on #{parent}: #{name}"
        end
      else
        result = name
      end

      raise ArgumentError, "\"name\" missing for encryption on #{parent}" if result.nil? || result.empty?
      result
    end

    # Factory method to create a lvm volume group.
    #
    # @param _parent [nil] (volume groups are toplevel)
    # @param args [Hash] volume group parameters:
    #   "vg_name"     volume group name
    #   "extent_size" extent size
    #
    # @return [Object] new volume group object
    #
    def create_lvm_vg(_parent, args)
      log.info("#{__method__}( #{args} )")
      @volumes = Set.new # contains both partitions and logical volumes

      vg_name = args["vg_name"]
      lvm_vg = LvmVg.create(@devicegraph, vg_name)

      extent_size = args["extent_size"] || DiskSize.zero
      lvm_vg.extent_size = extent_size if extent_size.to_i > 0

      lvm_vg
    end

    # Factory method to create a lvm logical volume.
    #
    # Some of the parameters ("mount_point", "label"...) really belong to the
    # file system which is a separate factory product, but it is more natural
    # to specify this for the logical volume, so those data are kept
    # in @file_system_data to be picked up in create_file_system when needed.
    #
    # @param parent [Object] volume group object
    #
    # @param args [Hash] lvm logical volume parameters:
    #   "lv_name"     logical volume name
    #   "size"        partition size
    #   "stripes"     number of stripes
    #   "stripe_size" stripe size
    #   "mount_point"   mount point for the associated file system
    #   "label"         file system label
    #   "uuid"          file system UUID
    #   "fstab_options" /etc/fstab options for the file system
    #
    # @return [String] device name of new logical volume
    #
    def create_lvm_lv(parent, args)
      log.info("#{__method__}( #{parent}, #{args} )")

      lv_name = args["lv_name"]
      raise ArgumentError, "\"lv_name\" missing for lvm_lv #{args} on #{vg_name}" unless lv_name
      raise ArgumentError, "Duplicate lvm_lv #{lv_name}" if @volumes.include?(lv_name)
      @volumes << lv_name

      size = args["size"] || DiskSize.zero
      raise ArgumentError, "\"size\" missing for lvm_lv #{lv_name}" unless args.key?("size")

      lvm_lv = parent.create_lvm_lv(lv_name, size)
      create_lvm_lv_stripe_parameters(lvm_lv, args)

      file_system_data_picker(lvm_lv.name, args)

      lvm_lv.name
    end

    # Helper class for create_lvm_lv handling the stripes related parameters.
    #
    def create_lvm_lv_stripe_parameters(lvm_lv, args)
      stripes = args["stripes"] || 0
      lvm_lv.stripes = stripes if stripes > 0

      stripe_size = args["stripe_size"] || DiskSize.zero
      lvm_lv.stripe_size = stripe_size if stripe_size.to_i > 0
    end

    # Factory method to create a lvm physical volume.
    #
    # @param parent [Object] volume group object
    #
    # @param args [Hash] lvm physical volume parameters:
    #   "blk_device" block device used by physical volume
    #
    # @return [Object] new physical volume object
    #
    def create_lvm_pv(parent, args)
      log.info("#{__method__}( #{parent}, #{args} )")

      blk_device_name = args["blk_device"]
      blk_device = BlkDevice.find_by_name(devicegraph, blk_device_name)

      parent.add_lvm_pv(blk_device)
    end

    # Factory method for a btrfs pseudo object to create subvolumes.
    #
    # @param parent [String] Name of the partition or LVM LV
    #
    # @param args [Hash] btrfs parameters:
    #   "default_subvolume"
    #
    # @return [String] Name of the partition or LVM LV
    #
    def create_btrfs(parent, args)
      log.info("#{__method__}( #{parent}, #{args} )")
      default_subvolume = args["default_subvolume"]
      if default_subvolume && !default_subvolume.empty?
        blk_device = BlkDevice.find_by_name(devicegraph, parent)
        filesystem = blk_device.filesystem
        if !filesystem || !filesystem.type.is?(:btrfs)
          raise HierarchyError, "No btrfs on #{parent}"
        end
        toplevel = filesystem.top_level_btrfs_subvolume
        subvolume = toplevel.create_btrfs_subvolume(default_subvolume)
        subvolume.set_default_btrfs_subvolume
      end
      parent
    end

    # Factory method for a btrfs subvolume
    #
    # @param parent [String] Name of the partition or LVM LV
    #
    # @param args [Hash] subvolume parameters:
    #   "path"  subvolume path without leading "@" or "/"
    #   "nocow" "no copy on write" attribute (default: false)
    #
    # @return [String] Name of the partition or LVM LV
    #
    def create_subvolume(parent, args)
      log.info("#{__method__}( #{parent}, #{args} )")
      path  = args["path"]
      nocow = args.fetch("nocow", false)
      raise ArgumentError, "No path for subvolume" unless path

      blk_device = BlkDevice.find_by_name(@devicegraph, parent)
      blk_device.filesystem.create_btrfs_subvolume(path, nocow)
    end

  private

    # Fetch an enum value
    # @raise [ArgumentError] if such value is not defined
    #
    # @param klass  [Class] class used to represent the enum
    # @param name   [String] name of the enum value
    # @param type   [String] type (description) of 'key'
    # @param object [String] name of the object that was being processed
    #
    def fetch(klass, name, type, object)
      value = klass.find(name)
      if !value
        available = klass.all.map(&:to_s)
        raise ArgumentError, "Invalid #{type} \"#{name}\" for #{object} - use one of #{available}"
      end
      value
    end
  end
  # rubocop:enable all
end
