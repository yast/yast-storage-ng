require "y2storage/storage_enum_wrapper"

module Y2Storage
  module Filesystems
    # Class to represent all the possible filesystem types
    #
    # This is a wrapper for the Storage::FsType enum
    class Type
      include StorageEnumWrapper

      wrap_enum "FsType"
    end
  end
end
