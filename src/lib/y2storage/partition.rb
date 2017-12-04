# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "y2storage/storage_class_wrapper"
require "y2storage/blk_device"
require "y2storage/disk"

module Y2Storage
  # A partition in a partitionable device (like a disk or RAID).
  #
  # This is a wrapper for Storage::Partition.
  class Partition < BlkDevice
    wrap_class Storage::Partition

    # @!method number
    #   Partition number extracted from its name (e.g. 2 for "/dev/sda2").
    #
    #   @raise [Storage::Exception] if name does not contain a number.
    #
    #   @return [Integer]
    storage_forward :number

    # @!method partition_table
    #   @return [PartitionTables::Base] the concrete subclass will depend
    #     on the type
    storage_forward :partition_table, as: "PartitionTables::Base"

    # @!method partitionable
    #   @return [Partitionable] device hosting the partition table.
    storage_forward :partitionable, as: "Partitionable"

    # @!attribute type
    #   {PartitionType Type} of the partition.
    #   @see PartitionType
    #
    #   @return [PartitionType]
    storage_forward :type, as: "PartitionType"
    storage_forward :type=

    # @!attribute id
    #   {PartitionId Id} of the partition.
    #   @see PartitionId
    #   @see #adapted_id= for a safer alternative to set this value
    #
    #   @return [PartitionId]
    storage_forward :id, as: "PartitionId"
    storage_forward :id=

    # @!method boot?
    #   Boot flag of the partition, only supported on Msdos.
    #
    #   @note
    #     1. To be
    #     [standard-conformant](https://en.wikipedia.org/wiki/Master_boot_record),
    #     setting the boot flag on a partition clears the boot flag on all
    #     other partitions of the partition table.
    #
    #     2. Partitions on GPT have no boot flag, "set <nr> boot on" with
    #     parted on GPT partitions only sets the partition type to EFI System
    #     Partition.
    #
    #   @return [Boolean]
    storage_forward :boot?

    # @!method boot=(flag)
    #   Set bot flag of the partition.
    #   @see boot?
    #
    #   @param flag [Boolean]
    storage_forward :boot=

    # @!method legacy_boot?
    #   Legacy boot flag of the partition, only supported on Gpt.
    #
    #   @return [Boolean]
    storage_forward :legacy_boot?

    # @!method legacy_boot=(flag)
    #   Set legacy boot flag of the partition.
    #
    #   @param flag [Boolean]
    storage_forward :legacy_boot=

    # @!method self.create(devicegraph, name, region, type)
    #   To get suitable values for this method, use
    #   {PartitionTables::Base#unused_partition_slots}
    #   @see Region
    #   @see #type
    #
    #   @param devicegraph [Devicegraph]
    #   @param name [String]
    #   @param region [Region]
    #   @param type [PartitionType]
    #   @return [Partition]
    storage_class_forward :create, as: "Partition"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String]
    #   @return [Partition] nil if there is no such partition.
    storage_class_forward :find_by_name, as: "Partition"

    # Disk the partition belongs to or nil if the partition is
    # not over a disk (e.g. a RAID).
    #
    # @return [Disk]
    def disk
      partitionable.is_a?(Disk) ? partitionable : nil
    end

    # Position of the first block of the region
    #
    # @return [Integer]
    def start
      region.start
    end

    # Position of the last block of the region
    #
    # @return [Integer]
    def end
      region.end
    end

    # Size of a single block
    #
    # @return [DiskSize]
    def block_size
      region.block_size
    end

    # Grain for alignment
    #
    # @see PartitionTables::Base#align_grain
    #
    # @return [DiskSize]
    def align_grain
      partition_table.align_grain
    end

    # Whether the first block of the partition is aligned according to
    # the partition table grain.
    #
    # @return [Boolean]
    def start_aligned?
      overhead = (block_size * start) % align_grain
      overhead.zero?
    end

    # Whether the final block of the partition is aligned according to
    # the partition table grain.
    #
    # @return [Boolean]
    def end_aligned?
      overhead = (block_size * self.end + block_size) % align_grain
      overhead.zero?
    end

    # All partitions in the given devicegraph, in no particular order
    #
    # @param devicegraph [Devicegraph]
    # @return [Array<Partition>]
    def self.all(devicegraph)
      Partitionable.all(devicegraph).map(&:partitions).flatten
    end

    # @return [String]
    def inspect
      "<Partition #{name} #{size}, #{region.show_range}>"
    end

    # Sets the id, ensuring its value is compatible with the partition table.
    #
    # In general, use this method instead of #id= if unsure.
    #
    # @see PartitionTables::Base#partition_id_for
    # @see #id
    #
    # @param partition_id [PartitionId]
    def adapted_id=(partition_id)
      self.id = partition_table.partition_id_for(partition_id)
    rescue ::Storage::Exception
      # if we made some mistake, log an error but don't break completely
      fallback_id = PartitionId::LINUX
      log.error "Failed to set partition id #{partition_id}, falling back to #{fallback_id}"
      self.id = fallback_id
    end

  protected

    def types_for_is
      super << :partition
    end
  end
end
