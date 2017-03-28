require "y2storage/storage_class_wrapper"
require "y2storage/partition_tables/base"

module Y2Storage
  module PartitionTables
    class Gpt < Base
      include StorageClassWrapper
      wrap_class Storage::Gpt

      storage_forward :enlarge
      storage_forward :enlarge=
      storage_forward :pmbr_boot
      storage_forward :pmbr_boot?
    end
  end
end
