require "y2storage/storage_class_wrapper"
require "y2storage/device"

module Y2Storage
  # Base class for most devices having a device name, udev path and udev ids.
  #
  # This is a wrapper for Storage::BlkDevice
  class BlkDevice < Device
    wrap_class Storage::BlkDevice, downcast_to: ["Partitionable", "Partition", "Encryption"]

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

    storage_forward :create_encryption, as: "Encryption", raise_errors: true

    # @!method blk_filesystem
    #   Filesystem directly placed in the device (no encryption or any other
    #   layer in between)
    #
    #   @return [Filesystems::BlkFilesystem] nil if the raw device is not
    #     formatted
    storage_forward :blk_filesystem, as: "Filesystems::BlkFilesystem"

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
    def plain_blk_filesystem
      encrypted? ? encryption.blk_filesystem : blk_filesystem
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
