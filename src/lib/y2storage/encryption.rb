require "y2storage/storage_class_wrapper"
require "y2storage/blk_device"

module Y2Storage
  # An encryption layer on a block device
  #
  # This is a wrapper for Storage::Encryption
  class Encryption < BlkDevice
    wrap_class Storage::Encryption

    storage_forward :blk_device, as: "BlkDevice"
    storage_forward :password
    storage_forward :password=

    storage_class_forward :all, as: "Encryption"
  end
end
