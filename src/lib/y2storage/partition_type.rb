require "y2storage/storage_enum_wrapper"

module Y2Storage
  # Class to represent all the possible partition types
  #
  # This is a wrapper for the Storage::PartitionType enum
  class PartitionType
    include StorageEnumWrapper

    wrap_enum "Storage::PartitionType", names: [:primary, :extended, :logical]
  end
end
