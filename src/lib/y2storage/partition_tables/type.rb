require "y2storage/storage_enum_wrapper"

module Y2Storage
  module PartitionTables
    # Class to represent all the possible partition table types
    #
    # This is a wrapper for the Storage::PtType enum
    class Type
      include StorageEnumWrapper

      wrap_enum "PtType"
    end
  end
end
