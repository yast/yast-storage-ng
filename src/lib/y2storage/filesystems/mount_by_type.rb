require "y2storage/storage_enum_wrapper"

module Y2Storage
  module Filesystems
    # Class to represent all the possible name schemas to use when mounting a
    # filesystem
    #
    # This is a wrapper for the Storage::MountByType enum
    class MountByType
      include StorageEnumWrapper

      wrap_enum "MountByType"
    end
  end
end
