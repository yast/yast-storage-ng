require "y2storage/storage_class_wrapper"
require "y2storage/filesystems/base"

module Y2Storage
  module Filesystems
    # Class to represent a NFS mount.
    #
    # The class does not provide functions to change the server or path since
    # that would create a completely different filesystem.
    #
    # This a wrapper for Storage::Nfs
    class Nfs < Base
      include StorageClassWrapper
      wrap_class Storage::Nfs

      storage_forward :server
      storage_forward :path

      storage_class_forward :all, as: "Filesystems::Nfs"
      storage_class_forward :find_by_server_and_path, as: "Filesystems::Nfs"
    end
  end
end
