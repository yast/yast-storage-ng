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

    storage_class_forward :all, as: "BlkDevice"
    storage_class_forward :find_by_name, as: "BlkDevice"

    storage_forward :name
    storage_forward :name=
    storage_forward :region, as: "Region"
    storage_forward :region=
    storage_forward :size, as: "DiskSize"
    storage_forward :size=
    storage_forward :sysfs_name
    storage_forward :sysfs_path
    storage_forward :udev_paths
    storage_forward :udev_ids
    storage_forward :dm_table_name
    storage_forward :dm_table_name=

    storage_forward :create_blk_filesystem, as: "Filesystems::BlkFilesystem", raise_errors: true

    # @!method create_filesystem
    #   Alias for create_blk_filesystem
    #
    #   @return [Filesystems::BlkFilesystem]
    alias_method :create_filesystem, :create_blk_filesystem

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
  end
end
