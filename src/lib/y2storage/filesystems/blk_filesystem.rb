require "y2storage/storage_class_wrapper"
require "y2storage/filesystems/base"

module Y2Storage
  module Filesystems
    class BlkFilesystem < Base
      include StorageClassWrapper
      wrap_class Storage::BlkFilesystem

      storage_forward :blk_devices, as: "BlkDevice"

      storage_forward :supports_label
      storage_forward :max_labelsize
      storage_forward :label
      storage_forward :label=

      storage_forward :supports_uuid
      storage_forward :uuid
      storage_forward :uuid=

      storage_forward :mkfs_options
      storage_forward :mkfs_options=
      storage_forward :tune_options
      storage_forward :tune_options=
      storage_forward :detect_content_info

      storage_class_forward :all, as: "Filesystems::BlkFilesystem"
      storage_class_forward :find_by_mountpoint, as: "Filesystems::BlkFilesystem"
      storage_class_forward :find_by_label, as: "Filesystems::BlkFilesystem"
    end
  end
end
