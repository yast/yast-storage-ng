require "y2storage/storage_class_wrapper"

module Y2Storage
  # An abstract base class of storage devices and a vertex in the Devicegraph.
  #
  # The Device class does not have a device name since some device types do
  # not have a intrinsic device name, e.g. btrfs.
  #
  # This is a wrapper for Storage::Device
  class Device
    include StorageClassWrapper
    wrap_class Storage::Device,
      downcast_to: ["BlkDevice", "Mountable", "PartitionTables::Base"]

    storage_forward :==
    storage_forward :!=
    storage_forward :sid
    storage_forward :ancestors, as: "Device"
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
