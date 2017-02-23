require "y2storage/storage_class_wrapper"
require "y2storage/partitionable"
require "y2storage/free_disk_space"

module Y2Storage
  class Disk < Partitionable
    include StorageClassWrapper
    wrap_class Storage::Disk

    storage_forward :rotational
    alias_method :rotational?, :rotational
    storage_forward :transport, as: "Transport"

    storage_class_forward :create, as: "Disk"
    storage_class_forward :all, as: "Disk"
    storage_class_forward :find_by_name, as: "Disk"

    # Free spaces inside the disk
    #
    # @return [Array<FreeDiskSpace>]
    def free_spaces
      # Unused disk
      return Array(FreeDiskSpace.new(self, region)) unless has_children
      # Disk in use, but with no partition table
      return [] if partition_table.nil?

      partition_table.unused_partition_slots.map do |slot|
        FreeDiskSpace.new(self, slot.region)
      end
    end

    def inspect
      "<Disk #{name} #{size}>"
    end

    # Checks if it's an USB disk
    #
    # @return [Boolean]
    def usb?
      transport.to_sym == :usb
    end

    # Checks whether it contains a GUID partition table
    #
    # @return [Boolean]
    def gpt?
      return false unless partition_table
      partition.type.to_sym == :gpt
    end

    # Executes the given block in a context in which the disk always have a
    # partition table if possible, creating a temporary one if needed.
    #
    # This allows any code to work under the assumption that a given disk
    # has an empty partition table of the YaST default type, even if that
    # partition table is not yet created.
    #
    # @see preferred_ptable_type
    #
    # @example With a disk that already has a partition table
    #   partitioned_disk.as_not_empty do
    #     partitioned_disk.partition_table # => returns the real partition table
    #   end
    #   partitioned_disk.partition_table # Still the same
    #
    # @example With a disk not partitioned but formatted (or a PV)
    #   lvm_pv_disk.as_not_empty do
    #     lvm_pv_disk.partition_table # => raises DeviceHasWrongType
    #   end
    #   lvm_pv_disk.partition_table # Still the same
    #
    # @example With a completely empty disk
    #   empty_disk.as_not_empty do
    #     empty_disk.partition_table # => a temporary PartitionTable
    #   end
    #   empty_disk.partition_table # Not longer there
    def as_not_empty
      fake_ptable = nil
      fake_ptable = create_partition_table(preferred_ptable_type) unless has_children

      yield
    ensure
      remove_descendants if fake_ptable
    end

    # Default partition type for newly created partitions
    #
    # This method is needed because YaST criteria does not necessarily match
    # the one followed by Storage::Disk#default_partition_table_type (which
    # defaults to MBR partition tables in many cases)
    def preferred_ptable_type
      # TODO: so far, DASD is not supported, so we always suggest GPT
      PartitionTables::Type.find(:gpt)
    end
  end
end
