require "y2storage/storage_class_wrapper"

module Y2Storage
  class Device
    include StorageClassWrapper
    wrap_class Storage::Device,
      downcast_to: ["BlkDevice", "Filesystems::Base", "PartitionTables::Base"]

    storage_forward :==
    storage_forward :!=
    storage_forward :sid
    storage_forward :exists_in_devicegraph?
    storage_forward :exists_in_probed?
    storage_forward :exists_in_staging?
    storage_forward :displayname
    storage_forward :detect_resize_info
    storage_forward :remove_descendants
    storage_forward :userdata
    storage_forward :userdata=
  end
end
