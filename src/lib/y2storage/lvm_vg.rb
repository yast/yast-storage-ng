require "y2storage/storage_class_wrapper"
require "y2storage/device"

module Y2Storage
  # A Volume Group of the Logical Volume Manager (LVM)
  #
  # This is a wrapper for Storage::LvmVg
  class LvmVg < Device
    include StorageClassWrapper
    wrap_class Storage::LvmVg

    # Volume group name. This is different from the device name
    storage_forward :vg_name
    storage_forward :vg_name=

    storage_forward :size, as: "DiskSize"
    storage_forward :extent_size, as: "DiskSize"
    storage_forward :extent_size=

    storage_forward :number_of_extents
    storage_forward :number_of_used_extents
    storage_forward :number_of_free_extents

    storage_forward :lvm_pvs, as: "LvmPv"
    storage_forward :add_lvm_pv, as: "LvmPv"
    storage_forward :remove_lvm_pv, as: "LvmPv"

    storage_forward :lvm_lvs, as: "LvmLv"
    storage_forward :create_lvm_lv, as: "LvmLv"
    storage_forward :delete_lvm_lv, as: "LvmLv"

    storage_class_forward :create, as: "LvmVg"
    storage_class_forward :all, as: "LvmVg"
    storage_class_forward :find_by_vg_name, as: "LvmVg"
  end
end
