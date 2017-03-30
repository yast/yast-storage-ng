require "y2storage/storage_class_wrapper"
require "y2storage/mountable"

module Y2Storage
  module Filesystems
    # Abstract class to represent a filesystem, either a local (BlkFilesystem) or
    # a network one, like NFS.
    #
    # This is a wrapper for Storage::Filesystem
    class Base < Mountable
      wrap_class Storage::Filesystem,
        downcast_to: ["Filesystems::BlkFilesystem", "Filesystems::Nfs"]

      storage_class_forward :all, as: "Filesystems::Base"
    end
  end
end
