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

    # @!method direct_blk_filesystem
    #   Filesystem directly placed in the device (no encryption or any other
    #   layer in between)
    #
    #   This is a wrapper for Storage::BlkDevice#blk_filesystem
    #
    #   @return [Filesystems::BlkFilesystem] nil if the raw device is not
    #     formatted
    storage_forward :direct_blk_filesystem, to: :blk_filesystem, as: "Filesystems::BlkFilesystem"
    private :direct_blk_filesystem

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

    # Filesystem in the device
    #
    # By default it returns a filesystem placed either directly on the device
    # or through an encryption layer.
    #
    # It can be forced to return only the direct filesystem (no encryption or any
    # other layer in between).
    #
    # @param [traverse_encryption] if set to false, the method will return nil
    #   if the device is encrypted, no matter if the encrypted device is
    #   formatted or not.
    # @return [Filesystems::BlkFilesystem] nil if the device is not formatted
    def blk_filesystem(traverse_encryption: true)
      return encryption.direct_blk_filesystem if encrypted? && traverse_encryption
      direct_blk_filesystem
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
