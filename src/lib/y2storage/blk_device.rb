# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "y2storage/storage_class_wrapper"
require "y2storage/device"
require "y2storage/hwinfo_reader"

module Y2Storage
  # Base class for most devices having a device name, udev path and udev ids.
  #
  # This is a wrapper for Storage::BlkDevice
  class BlkDevice < Device
    wrap_class Storage::BlkDevice,
      downcast_to: ["Partitionable", "Partition", "Encryption", "LvmLv"]

    DEVDIR = "/dev/".freeze

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<BlkDevice>] all the block devices in the given devicegraph
    storage_class_forward :all, as: "BlkDevice"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String] kernel-style device name (e.g. "/dev/sda1")
    #   @return [BlkDevice] nil if there is no such block device
    storage_class_forward :find_by_name, as: "BlkDevice"

    # @!attribute name
    #   @return [String] kernel-style device name
    #     (e.g. "/dev/sda2" or "/dev/vg_name/lv_name")
    storage_forward :name
    storage_forward :name=

    # @!attribute region
    #   @return [Region]
    storage_forward :region, as: "Region"
    storage_forward :region=

    # @!attribute size
    #   @return [DiskSize]
    storage_forward :size, as: "DiskSize"
    storage_forward :size=

    # @!method sysfs_name
    #   @return [String] e.g. "sda2" or "dm-1"
    storage_forward :sysfs_name

    # @!method sysfs_path
    #   e.g. "/devices/pci00:0/00:0:1f.2/ata1/host0/target0:0:0/0:0:0:0/block/sda/sda2"
    #   or "/devices/virtual/block/dm-1"
    #   @return [String]
    storage_forward :sysfs_path

    # Full paths of all the udev by-* links. an empty array for devices
    # not handled by udev.
    # @see #udev_full_paths
    # @see #udev_full_ids
    # @see #udev_full_uuid
    # @see #udev_full_label
    # @return [Array<String>]
    def udev_full_all
      res = udev_full_paths.concat(udev_full_ids)
      res << udev_full_uuid << udev_full_label

      res.compact
    end

    # @!method udev_paths
    #   Names of all the udev by-path links. An empty array for devices
    #   not handled by udev.
    #   E.g. ["pci-0000:00:1f.2-ata-1-part2"]
    #   @see #udev_full_paths
    #   @return [Array<String>]
    storage_forward :udev_paths

    # Full paths of all the udev by-path links. An empty array for devices
    # not handled by udev.
    # E.g. ["/dev/disk/by-path/pci-0000:00:1f.2-ata-1-part2"]
    # @see #udev_paths
    # @return [Array<String>]
    def udev_full_paths
      udev_paths.map { |path| File.join("/dev", "disk", "by-path", path) }
    end

    # @!method udev_ids
    #   Names of all the udev by-id links. An empty array for devices
    #   not handled by udev.
    #   E.g. ["scsi-350014ee658db9ee6"]
    #   @see #udev_full_ids
    #   @return [Array<String]
    storage_forward :udev_ids

    # Full paths of all the udev by-id links. An empty array for devices
    # not handled by udev.
    # E.g. ["/dev/disk/by-id/scsi-350014ee658db9ee6"]
    # @see #udev_ids
    # @return [Array<String>]
    def udev_full_ids
      udev_ids.map { |id| File.join("/dev", "disk", "by-id", id) }
    end

    # @!attribute dm_table_name
    #   Device-mapper table name. Empty if this is not a device-mapper device.
    #   @return [String]
    storage_forward :dm_table_name
    storage_forward :dm_table_name=

    # @!method create_blk_filesystem(fs_type)
    #   Creates a new filesystem object on top of the device in order to format it.
    #
    #   @param fs_type [Filesystems::Type]
    #   @return [Filesystems::BlkFilesystem]
    storage_forward :create_blk_filesystem, as: "Filesystems::BlkFilesystem", raise_errors: true
    alias_method :create_filesystem, :create_blk_filesystem

    # @!method create_encryption(dm_name)
    #   Creates a new encryption object on top of the device.
    #
    #   If the blk device has children, the children will become children of
    #   the encryption device.
    #
    #   @note: NEVER use this if any child of the block device already exists
    #   in the real system. It will fail during commit.
    #
    #   @param dm_name [String] see #dm_table_name
    #   @return [Encryption]
    storage_forward :create_encryption, as: "Encryption", raise_errors: true

    # @!method remove_encryption
    #   Removes an encryption device on the block device.
    #
    #   If the encryption device has children, the children will become direct
    #   children of the block device.
    #
    #   @note: NEVER use this if any child of the encryption device already
    #   exists in the real system. It will fail during commit.
    #
    #   @raise [Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType] if
    #     the device is not encrypted.
    storage_forward :remove_encryption, raise_errors: true

    # @!method direct_blk_filesystem
    #   Filesystem directly placed in the device (no encryption or any other
    #   layer in between)
    #
    #   This is a wrapper for Storage::BlkDevice#blk_filesystem
    #
    #   @return [Filesystems::BlkFilesystem] nil if the raw device is not
    #     formatted
    storage_forward :direct_blk_filesystem,
      to: :blk_filesystem, as: "Filesystems::BlkFilesystem", check_with: :has_blk_filesystem

    # @!method encryption
    #   Encryption device directly placed on top of the device
    #
    #   @return [Encryption] nil if the device is not encrypted
    storage_forward :encryption, as: "Encryption", check_with: :has_encryption

    # Checks whether the device is encrypted
    #
    # @return [boolean]
    def encrypted?
      !encryption.nil?
    end

    # Filesystem placed in the device, either directly or through an encryption
    # layer.
    #
    # @return [Filesystems::BlkFilesystem] nil if neither the raw device or its
    #   encrypted version are formatted
    def blk_filesystem
      encrypted? ? encryption.direct_blk_filesystem : direct_blk_filesystem
    end

    alias_method :filesystem, :blk_filesystem

    # Checks whether the device is formatted
    #
    # @return [Boolean]
    def formatted?
      !filesystem.nil?
    end

    # Removes the filesystem when the device is formatted
    def delete_filesystem
      return if filesystem.nil?
      remove_descendants
    end

    # LVM physical volume defined on top of the device, either directly or
    # through an encryption layer.
    #
    # @return [LvmPv] nil if neither the raw device or its encrypted version
    #   are used as physical volume
    def lvm_pv
      descendants.detect { |dev| dev.is?(:lvm_pv) && dev.plain_blk_device == plain_device }
    end

    # LVM physical volume defined directly on top of the device (no encryption
    # or any other layer in between)
    #
    # @return [LvmPv] nil if the raw device is not used as physical volume
    def direct_lvm_pv
      descendants.detect { |dev| dev.is?(:lvm_pv) && dev.blk_device == self }
    end

    # MD array defined on top of the device, either directly or through an
    # encryption layer.
    #
    # @return [Md] nil if neither the raw device or its encrypted version
    #   are used by an MD RAID device
    def md
      descendants.detect { |dev| dev.is?(:md) && dev.plain_devices.include?(plain_device) }
    end

    # MD array defined directly on top of the device (no encryption or any
    # other layer in between)
    #
    # @return [Md] nil if the raw device is not used by any MD RAID device
    def direct_md
      descendants.detect { |dev| dev.is?(:md) && dev.devices.include?(self) }
    end

    # Label of the filesystem, if any
    # @return [String, nil]
    def filesystem_label
      return nil unless blk_filesystem
      blk_filesystem.label
    end

    # full path of the udev by-label link or `nil` if it does not exist.
    # e.g. "/dev/disk/by-label/DATA"
    # @see #udev_paths
    # @return [String]
    def udev_full_label
      label = filesystem_label

      return nil if label.nil? || label.empty?
      File.join("/dev", "disk", "by-label", label)
    end

    # UUID of the filesystem, if any
    # @return [String, nil]
    def filesystem_uuid
      return nil unless blk_filesystem
      blk_filesystem.uuid
    end

    # full path of the udev by-uuid link or `nil` if it does not exist.
    # e.g. "/dev/disk/by-uuid/a1dc747af-6ef7-44b9-b4f8-d200a5f933ec"
    # @see #udev_paths
    # @return [String]
    def udev_full_uuid
      uuid = filesystem_uuid

      return nil if uuid.nil? || uuid.empty?
      File.join("/dev", "disk", "by-uuid", uuid)
    end

    # Type of the filesystem, if any
    # @return [Filesystems::Type, nil]
    def filesystem_type
      return nil unless blk_filesystem
      blk_filesystem.type
    end

    # Mount point of the filesystem, if any
    # @return [String, nil]
    def filesystem_mountpoint
      return nil unless blk_filesystem
      blk_filesystem.mountpoint
    end

    # Non encrypted version of this device
    #
    # For most subclasses, this will simply return the device itself. To be
    # redefined by encryption-related subclasses.
    #
    # @return [BlkDevice]
    def plain_device
      self
    end

    # Checks whether a new filesystem (encrypted or not) should be created for
    # this device
    #
    # @param initial_devicegraph [Devicegraph] devicegraph to use as starting
    #   point when calculating the actions to perform
    # @return [Boolean]
    def to_be_formatted?(initial_devicegraph)
      return false unless blk_filesystem
      !blk_filesystem.exists_in_devicegraph?(initial_devicegraph)
    end

    # Last part of {#name}
    #
    # @example Get the device basename
    #   device.name     # => "/dev/sda"
    #   device.basename # => "sda"
    #
    # @return [String]
    def basename
      name.split("/").last
    end

    # Return hardware information for the device
    #
    # @return [OpenStruct,nil] Hardware information; nil if no information was found.
    #
    # @see Y2Storage::HWInfoReader
    def hwinfo
      Y2Storage::HWInfoReader.instance.for_device(name)
    end

    # Regular expression matching with the name of this device.
    #
    # @see .name_regexps
    def name_regexp
      self.class.name_regexps.find { |regexp| regexp.match?(name) }
    end

    # To be redefined by each subclass, possible structures of a device name.
    #
    # Each regular expression must capture (using parenthesis) all the variable
    # parts of the name, that will be compared using #compare_substrings
    #
    # @return [Array<Regexp>]
    def self.name_regexps
      []
    end

    # All the devices of the correspondig class found in the given devicegraph,
    # sorted by name
    #
    # See {#compare_by_name} to know more about the sorting.
    #
    # @param devicegraph [Devicegraph]
    # @return [Array<BlkDevice>]
    def self.sorted_by_name(devicegraph)
      all(devicegraph).sort { |a, b| a.compare_by_name(b) }
    end

    # Compare to another device by name, used for sorting sets of
    # block devices.
    #
    # Using this method to compare and sort would result is something similar
    # to alphabetical order but with some desired exceptions like:
    #
    # * /dev/sda, /dev/sdb, ..., /dev/sdaa
    # * /dev/md1, /dev/md2, ..., /dev/md10
    #
    # @param other [BlkDevice]
    # @return [Integer] -1 if this object should appear before the one passed as
    #   argument (less than). 1 otherwise.
    def compare_by_name(other)
      # Check if both names follow the same structure
      if compatible_regexps?(other)
        match = name_regexp.match(name)
        other_match = other.name_regexp.match(other.name)

        # If both names follow the same structure, compare by order each one of
        # the variable parts by size and alphabetical order
        match.captures.each_with_index do |capture, index|
          other_capture = other_match.captures[index]
          # Turns out they were equivalent until this point... but self if
          # longer
          return 1 if other_capture.nil?

          result = compare_substrings(capture, other_capture)
          return result unless result.zero?
        end

        # They were equivalent until the end of self, but other is longer
        return -1
      end

      # The names don't share a matching expression, fallback to pure
      # alphabetical order
      name <=> other.name
    end

    # Whether the #name_regexp of this device is comparable with the
    # #name_regexp of another.
    #
    # Two regexp are comparable if they are the same (like comparing a /dev/vda
    # disk with a /dev/vdb DASD) or if one is an extended version of the other
    # (like comparing a /dev/sdaa2 partition with a /dev/sdb disk).
    #
    # @return [Boolean]
    def compatible_regexps?(other)
      return false if name_regexp.nil? || other.name_regexp.nil?
      regexp_string = name_regexp.inspect.chomp("/")
      other_string = other.name_regexp.inspect.chomp("/")
      regexp_string.start_with?(other_string) || other_string.start_with?(regexp_string)
    end

    # Compare two strings by size and, in case of tie, by alphabetical order
    def compare_substrings(lhs, rhs)
      by_size = lhs.size <=> rhs.size
      by_size.zero? ? lhs <=> rhs : by_size
    end
  end
end
