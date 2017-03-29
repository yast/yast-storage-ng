require "y2storage/storage_class_wrapper"

module Y2Storage
  module PartitionTables
    # A slot within a partition table
    #
    # This is a wrapper for Storage::PartitionSlot
    class PartitionSlot
      include StorageClassWrapper
      wrap_class Storage::PartitionSlot

      storage_forward :region, as: "Region"
      storage_forward :nr
      storage_forward :name
      storage_forward :possible?
      storage_forward :primary_slot
      storage_forward :primary_possible
      storage_forward :extended_slot
      storage_forward :extended_possible
      storage_forward :logical_slot
      storage_forward :logical_possible

      alias_method :primary_slot?, :primary_slot
      alias_method :primary_possible?, :primary_possible
      alias_method :extended_slot?, :extended_slot
      alias_method :extended_possible?, :extended_possible
      alias_method :logical_slot?, :logical_slot
      alias_method :logical_possible?, :logical_possible

      def inspect
        nice_size = Y2Storage::DiskSize.B(region.length * region.block_size.to_i)
        "<PartitionSlot #{nr} #{name} #{flags_string} #{nice_size}, #{region.show_range}>"
      end

      alias_method :to_s, :inspect

    private

      # rubocop:disable Metrics/CyclomaticComplexity
      def flags_string
        flags = ""
        flags << "P" if primary_slot
        flags << "p" if primary_possible
        flags << "E" if extended_slot
        flags << "e" if extended_possible
        flags << "L" if logical_slot
        flags << "l" if logical_possible
        flags
      end
      # rubocop:enable all
    end
  end
end
