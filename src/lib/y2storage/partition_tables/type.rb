require "y2storage/storage_enum_wrapper"

module Y2Storage
  module PartitionTables
    class Type
      include StorageEnumWrapper

      wrap_enum "Storage::PtType", names: [:pt_unknown, :pt_loop, :msdos, :gpt, :dasd, :mac]
    end
  end
end
