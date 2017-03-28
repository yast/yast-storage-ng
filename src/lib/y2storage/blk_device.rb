require "y2storage/storage_class_wrapper"
require "y2storage/device"

module Y2Storage
  class BlkDevice < Device
    include StorageClassWrapper
    wrap_class Storage::BlkDevice, downcast_to: [ "Partitionable", "Partition"]

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
    storage_forward :create_blk_filesystem, as: "Filesystems::BlkFilesystem"
    storage_forward :bkl_filesystem, as: "Filesystems::BlkFilesystem"

    storage_class_forward :all, as: "BlkDevice"
    storage_class_forward :find_by_name, as: "BlkDevice"
  end
end
