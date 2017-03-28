require "y2storage/storage_class_wrapper"
require "y2storage/blk_device"
require "y2storage/disk"

module Y2Storage
  class Partition < BlkDevice
    include StorageClassWrapper
    wrap_class Storage::Partition

    storage_forward :number
    storage_forward :partition_table, as: "PartitionTables::Base"
    storage_forward :partitionable, as: "Partitionable"
    storage_forward :type, as: "PartitionType"
    storage_forward :type=
    storage_forward :id, as: "PartitionId"
    storage_forward :id=
    storage_forward :boot?
    storage_forward :boot=
    storage_forward :legacy_boot?
    storage_forward :legacy_boot=


    storage_class_forward :create, as: "Partition"
    storage_class_forward :find_by_name, as: "Partition"

    def disk
      partitionable.is_a?(Disk) ? partitionable : nil
    end

    def self.all(devicegraph)
      Partitionable.all(devicegraph).map(&:partitions).flatten
    end

    def inspect
      "<Partition #{name} #{size}, #{region.show_range}>"
    end
  end
end
