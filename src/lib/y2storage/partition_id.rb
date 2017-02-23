require "y2storage/storage_enum_wrapper"

module Y2Storage
  class PartitionId
    include StorageEnumWrapper

    wrap_enum "Storage::ID", names: [
      :dos12, :dos16, :dos32, :ntfs, :extended, :prep, :linux, :swap, :lvm, :raid,
      :unknown, :bios_boot, :windows_basic_data, :microsoft_reserved
    ]
  end
end
