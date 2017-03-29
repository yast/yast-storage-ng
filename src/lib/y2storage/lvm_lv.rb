require "y2storage/storage_class_wrapper"
require "y2storage/blk_device"

module Y2Storage
  # A logical volume of the Logical Volume Manager (LVM)
  #
  # This is a wrapper for Storage::LvmLv
  class LvmLv < BlkDevice
    include StorageClassWrapper
    wrap_class Storage::LvmLv

    storage_forward :lv_name
    storage_forward :lvm_vg, as: "LvmVg"

    storage_class_forward :all, as: "LvmLv"
  end
end
