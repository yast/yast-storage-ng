require "y2storage/storage_class_wrapper"
require "y2storage/blk_device"
require "y2storage/partition_tables"

module Y2Storage
  class Partitionable < BlkDevice
    include StorageClassWrapper
    wrap_class Storage::Partitionable, downcast_to: "Disk"

    storage_forward :range
    storage_forward :range=
    storage_forward :default_partition_table_type, as: "PartitionTables::Type"
    storage_forward :possible_partition_table_types, as: "PartitionTables::Type"
    storage_forward :create_partition_table, as: "PartitionTables::Base"
    storage_forward :partition_table, as: "PartitionTables::Base"
    storage_forward :topology

    storage_class_forward :all, as: "Partitionable"

    # Minimal grain of the partitionable
    #
    # @return [DiskSize]
    def min_grain
      DiskSize.new(topology.minimal_grain)
    end

    def partitions
      partition_table ? partition_table.partitions : []
    end
  end
end
