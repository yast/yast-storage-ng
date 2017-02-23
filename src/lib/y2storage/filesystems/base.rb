require "y2storage/storage_class_wrapper"
require "y2storage/device"

module Y2Storage
  module Filesystems
    class Base < Device
      include StorageClassWrapper
      wrap_class Storage::Filesystem, downcast_to: "Filesystems::BlkFilesystem"

      storage_forward :type, as: "Filesystems::Type"
      storage_forward :mountpoints
      storage_forward :mountpoints=
      storage_forward :add_mountpoint
      storage_forward :mount_by, as: "Filesystems::MountByType"
      storage_forward :mount_by=
      storage_forward :fstab_options
      storage_forward :fstab_options=

      storage_class_forward :all, as: "Filesystems::Base"
      storage_class_forward :find_by_mountpoint, as: "Filesystems::Base"
    end
  end
end
