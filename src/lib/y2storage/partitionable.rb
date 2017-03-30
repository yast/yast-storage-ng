require "y2storage/storage_class_wrapper"
require "y2storage/blk_device"
require "y2storage/partition_tables"

module Y2Storage
  # Base class for all the devices that can contain a partition table, like
  # disks or RAID devices
  #
  # This is a wrapper for Storage::Partitionable
  class Partitionable < BlkDevice
    wrap_class Storage::Partitionable, downcast_to: ["Disk"]

    storage_forward :range
    storage_forward :range=
    storage_forward :default_partition_table_type, as: "PartitionTables::Type"
    storage_forward :possible_partition_table_types, as: "PartitionTables::Type"
    storage_forward :create_partition_table, as: "PartitionTables::Base"
    storage_forward :partition_table, as: "PartitionTables::Base"
    storage_forward :topology

    storage_class_forward :all, as: "Partitionable"

    # Minimal grain of the partitionable
    # TODO: provide a good definition for "grain"
    #
    # @return [DiskSize]
    def min_grain
      DiskSize.new(topology.minimal_grain)
    end

    def partitions
      partition_table ? partition_table.partitions : []
    end

    # Checks whether it contains a GUID partition table
    #
    # @return [Boolean]
    def gpt?
      return false unless partition_table
      partition_table.type.to_sym == :gpt
    end
  end
end
