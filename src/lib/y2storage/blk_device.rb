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

module Y2Storage
  # Base class for most devices having a device name, udev path and udev ids.
  #
  # This is a wrapper for Storage::BlkDevice
  class BlkDevice < Device
    wrap_class Storage::BlkDevice,
      downcast_to: ["Partitionable", "Partition", "Encryption", "LvmLv"]

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
    #   @param dm_name [String] see #dm_table_name
    #   @return [Encryption]
    storage_forward :create_encryption, as: "Encryption", raise_errors: true

    # @!method direct_blk_filesystem
    #   Filesystem directly placed in the device (no encryption or any other
    #   layer in between)
    #
    #   This is a wrapper for Storage::BlkDevice#blk_filesystem
    #
    #   @return [Filesystems::BlkFilesystem] nil if the raw device is not
    #     formatted
    storage_forward :direct_blk_filesystem, to: :blk_filesystem, as: "Filesystems::BlkFilesystem"

    # @!method encryption
    #   Encryption device directly placed on top of the device
    #
    #   @return [Encryption] nil if the device is not encrypted
    storage_forward :encryption, as: "Encryption"

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

    # Label of the filesystem, if any
    # @return [String, nil]
    def filesystem_label
      return nil unless blk_filesystem
      blk_filesystem.label
    end

    # UUID of the filesystem, if any
    # @return [String, nil]
    def filesystem_uuid
      return nil unless blk_filesystem
      blk_filesystem.uuid
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
  end
end
