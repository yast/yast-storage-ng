#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2016] SUSE LLC
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
require "y2storage/abstract_device_factory.rb"
require "y2storage/disk_size.rb"
require "y2storage/enum_mappings.rb"

module Y2Storage
  #
  # Factory class to generate faked devices in a device graph.
  # This is typically used with a YAML file.
  # Use the inherited load_yaml_file() to start the process.
  #
  # rubocop:disable Metrics/ClassLength
  #
  class FakeDeviceFactory < AbstractDeviceFactory
    include EnumMappings

    # Valid toplevel products of this factory
    VALID_TOPLEVEL  = ["disk", "lvm_vg"]

    # Valid hierarchy within the products of this factory.
    # This indicates the permitted children types for each parent.
    VALID_HIERARCHY =
      {
        "disk"       => ["partition_table", "partitions", "file_system"],
        "partitions" => ["partition", "free"],
        "partition"  => ["file_system", "encryption"],
        "encryption" => ["file_system"],
        "lvm_vg"     => ["lvm_lvs", "lvm_pvs"],
        "lvm_lvs"    => ["lvm_lv"],
        "lvm_lv"     => ["file_system", "encryption"],
        "lvm_pvs"    => ["lvm_pv"],
        "lvm_pv"     => []
      }

    FILE_SYSTEM_PARAM = ["mount_point", "label", "uid", "fstab_options"]

    # Valid parameters for each product of this factory.
    # Sub-products are not listed here.
    VALID_PARAM =
      {
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
        "lvm_lv"          => ["lv_name", "size", "stripes", "stripe_size"
        ].concat(FILE_SYSTEM_PARAM),
        "lvm_pv"          => ["blk_device"]
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
      @disks = Set.new
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
    #
    # FIXME: this method is too complex. It offends three different cops
    # related to complexity.
    # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    def create_disk(_parent, args)
      @partitions     = {}
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
        r = ::Storage::Region.new(0, size.size / block_size.size, block_size.size)
        disk = ::Storage::Disk.create(@devicegraph, name, r)
      else
        disk = ::Storage::Disk.create(@devicegraph, name)
        disk.size = size.size
      end
      set_topology_attributes!(disk, args)
      # range (number of partitions that the kernel can handle) used to be
      # 16 for scsi and 64 for ide. Now it's 256 for most of them.
      disk.range = args["range"] || 256
      name
    end
    # rubocop:enable all

    # Modifies topology settings of the disk according to factory arguments
    #
    # @param disk [::Storage::Disk]
    # @param args [Hash] disk parameters. @see #create_disk
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
      disk = ::Storage::Disk.find_by_name(@devicegraph, disk_name)
      ptable = disk.create_partition_table(ptable_type)
      if ::Storage.msdos?(ptable) && @mbr_gap
        ::Storage.to_msdos(ptable).minimal_mbr_gap = @mbr_gap.size
      end
      disk_name
    end

    # Partition table type represented by a string
    #
    # @param string [String] usually from a YAML file
    # @return [Fixnum]
    def str_to_ptable_type(string)
      # Allow different spelling
      string = "msdos" if string.casecmp("ms-dos").zero?
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
    # rubocop:disable  Metrics/MethodLength
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
      raise ArgumentError, "Duplicate partition #{part_name}" if @partitions.include?(part_name)

      file_system_data_picker(part_name, args)

      id = id.to_i(16) if id.is_a?(::String) && id.start_with?("0x")
      id   = fetch(PARTITION_IDS,   id,   "partition ID",   part_name) unless id.is_a?(Fixnum)
      type = fetch(PARTITION_TYPES, type, "partition type", part_name)
      align = fetch(ALIGN_POLICIES, align, "align policy", part_name) if align

      disk = ::Storage::Disk.find_by_name(devicegraph, disk_name)
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
        start_block = region.start + @free_blob.size / region.block_size
      end
      @free_blob = nil

      # if start has been specified, use it
      start_block = start.size / region.block_size if start

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

      # align partition if specified
      region = disk.topology.align(region, align) if align

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
      mount_point   = fs_param["mount_point"]
      label         = fs_param["label"]
      uuid          = fs_param["uuid"]
      fstab_options = fs_param["fstab_options"]
      encryption    = fs_param["encryption"]

      if !encryption.nil?
        log.info("file system is on encrypted device #{encryption}")
        parent = encryption
      end
      blk_device = ::Storage::BlkDevice.find_by_name(@devicegraph, parent)
      file_system = blk_device.create_filesystem(fs_type)
      file_system.add_mountpoint(mount_point) if mount_point
      file_system.label = label if label
      file_system.uuid = uuid if uuid
      set_fstab_options(file_system, fstab_options)
      parent
    end

    # Picks some parameters that are really file system related from args
    # and places them in @partitions to be picked up later by
    # create_file_system.
    #
    # @param [String] name of blk_device file system is on
    #
    # @param args [Hash] hash with data from yaml file
    #
    def file_system_data_picker(name, args)
      @partitions[name] = args.select do |k, _v|
        ["mount_point", "label", "uuid", "fstab_options", "encryption"].include?(k)
      end
    end

    # Assigns the value of Filesystem#fstab_options. A direct assignation of a
    # regular Ruby collection (like Array) will not work because
    # Filesystem#fstab_options= expects an argument with a very specific SWIG
    # type (std::list)
    #
    # @param [Storage::Filesystem] File system being created
    # @param [#each] Collection of strings to assign
    def set_fstab_options(file_system, fstab_options)
      return if fstab_options.nil? || fstab_options.empty?
      fstab_options.each { |opt| file_system.fstab_options << opt }
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
      @free_blob = size if size && size.size > 0
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

      blk_parent = Storage::BlkDevice.find_by_name(@devicegraph, parent)
      encryption = blk_parent.create_encryption(name)
      encryption.password = password unless password.nil?
      if @partitions.key?(parent)
        # Notify create_file_system that this partition is encrypted
        @partitions[parent]["encryption"] = encryption.name
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

      @partitions = {}

      vg_name = args["vg_name"]
      lvm_vg = ::Storage::LvmVg.create(@devicegraph, vg_name)

      extent_size = args["extent_size"] || DiskSize.zero
      lvm_vg.extent_size = extent_size.size if extent_size.size > 0

      lvm_vg
    end

    # Factory method to create a lvm logical volume.
    #
    # Some of the parameters ("mount_point", "label"...) really belong to the
    # file system which is a separate factory product, but it is more natural
    # to specify this for the logical volume, so those data are kept in
    # @partitions to be picked up in create_file_system when needed.
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
      raise ArgumentError, "Duplicate lvm_lv #{lv_name}" if @partitions.include?(lv_name)

      size = args["size"] || DiskSize.zero
      raise ArgumentError, "\"size\" missing for lvm_lv #{lv_name}" if size.zero?

      lvm_lv = parent.create_lvm_lv(lv_name, size.size)

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
      lvm_lv.stripe_size = stripe_size.size if stripe_size.size > 0
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
      blk_device = ::Storage::BlkDevice.find_by_name(devicegraph, blk_device_name)

      parent.add_lvm_pv(blk_device)
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
  # rubocop:enable all
end
