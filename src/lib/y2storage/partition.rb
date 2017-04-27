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
    #   @return [Fixnum]
    storage_forward :number

    # @!method partition_table
    #   @return [PartitionTables::Base] the concrete subclass will depend.
    #     on the type
    storage_forward :partition_table, as: "PartitionTables::Base"

    # @!method partitionable
    #   @return [Partitionable] device hosting the partition table.
    storage_forward :partitionable, as: "Partitionable"

    # @!attribute type
    #   Type of the partition.
    #   @see PartitionType
    #
    #   @return [PartitionType]
    storage_forward :type, as: "PartitionType"
    storage_forward :type=

    # @!attribute id
    #   Id of the partition.
    #   @see PartitionId
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

    # All partitions in the given devicegraph.
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

  protected

    def types_for_is
      super << :partition
    end
  end
end
