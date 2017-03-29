require "y2storage/storage_class_wrapper"
require "y2storage/device"

module Y2Storage
  module PartitionTables
    # Base class for the different kinds of partition tables.
    #
    # This is a wrapper for Storage::PartitionTable
    class Base < Device
      wrap_class Storage::PartitionTable,
        downcast_to: ["PartitionTables::Msdos", "PartitionTables::Gpt"]

      storage_forward :type, as: "PartitionTables::Type"
      storage_forward :create_partition, as: "Partition"
      storage_forward :partitions, as: "Partition"
      storage_forward :partitionable, as: "Disk"
      storage_forward :max_primary
      storage_forward :num_primary
      storage_forward :max_logical
      storage_forward :num_logical
      storage_forward :extended_possible
      storage_forward :has_extended
      storage_forward :unused_partition_slots, as: "PartitionTables::PartitionSlot"
      storage_forward :partition_boot_flag_supported?
      storage_forward :partition_legacy_boot_flag_supported?

      def inspect
        parts = partitions.map(&:inspect)
        slots = unused_partition_slots.map(&:to_s)
        "<PartitionTable #{self}[#{num_children}] #{parts}#{slots}>"
      end
    end
  end
end
