require "y2storage/storage_class_wrapper"
require "y2storage/partition_tables/base"

module Y2Storage
  module PartitionTables
    class Msdos < Base
      include StorageClassWrapper
      wrap_class Storage::Msdos

      storage_forward :minimal_mbr_gap, as: "DiskSize"
      storage_forward :minimal_mbr_gap=
    end
  end
end
