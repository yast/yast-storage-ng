require "y2storage/storage_class_wrapper"
require "y2storage/device"

module Y2Storage
  # A physical volume of the Logical Volume Manager (LVM)
  #
  # This is a wrapper for Storage::LvmPv
  class LvmPv < Device
    wrap_class Storage::LvmPv

    storage_class_forward :all, as: "LvmPv"

    storage_forward :lvm_vg, as: "LvmVg"

    # @!method blk_device
    #   Block device directly hosting the PV. That is, for encrypted PVs it
    #   returns the encryption device.
    #
    #   @return [BlkDevice]
    storage_forward :blk_device, as: "BlkDevice"

    # Raw (non encrypted) version of the device hosting the PV.
    #
    # If the PV is not encrypted, this is equivalent to #blk_device, otherwise
    # it returns the original device instead of the encryption one.
    #
    # @return [BlkDevice]
    def plain_blk_device
      blk_device.is_a?(Encryption) ? blk_device.blk_device : blk_device
    end
  end
end
