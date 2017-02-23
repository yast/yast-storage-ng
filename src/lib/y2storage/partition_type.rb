require "y2storage/storage_enum_wrapper"

module Y2Storage
  class PartitionType
    include StorageEnumWrapper

    wrap_enum "Storage::PartitionType", names: [:primary, :extended, :logical]
  end
end
