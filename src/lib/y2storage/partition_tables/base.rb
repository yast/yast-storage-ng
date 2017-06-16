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
require "y2storage/device"
require "y2storage/partition_tables/type"

module Y2Storage
  module PartitionTables
    # Base class for the different kinds of partition tables.
    #
    # This is a wrapper for Storage::PartitionTable
    class Base < Device
      wrap_class Storage::PartitionTable,
        downcast_to: ["PartitionTables::Msdos", "PartitionTables::Gpt", "PartitionTables::Dasd"]

      # @!method type
      #   @return [PartitionTables::Type]
      storage_forward :type, as: "PartitionTables::Type"

      # @!method create_partition(name, region, type)
      #   Creates a new partition.
      #
      #   @raise [Storage::DifferentBlockSizes] if the region don't fit the
      #     device
      #   @raise [Storage::Exception] if it's impossible to create the partition
      #     for any other reason. @see Partition.create
      #
      #   @param [String] name of the device, kernel-style (e.g. "/dev/sda1")
      #   @param [Region] region to be used by the new partition
      #   @param [PartitionType] type of the new partition
      #   @return [Partition]
      storage_forward :create_partition, as: "Partition"

      # @!method delete_partition(partition)
      #    Deletes the given partition in the partition table and all its
      #    descendants.
      #
      #    @param partition [Partition]
      storage_forward :delete_partition

      # @!method partitions
      #   All the partitions, sorted by partition number
      #   @return [Array<Partition>]
      storage_forward :partitions, as: "Partition"

      # @!method partitionable
      #   @return [Partitionable] device hosting the partition table
      storage_forward :partitionable, as: "Partitionable"

      # @!method max_primary
      #   @return [Fixnum] maximum supported number of primary partitions
      storage_forward :max_primary

      # @!method num_primary
      #   @return [Fixnum] current amount of primary partitions
      storage_forward :num_primary

      # @!method max_logical
      #   @return [Fixnum] maximum supported number of logical partitions
      storage_forward :max_logical

      # @!method num_logical
      #   @return [Fixnum] current amount of logical partitions
      storage_forward :num_logical

      # @!method extended_possible?
      #   @return [Boolean] whether is possible to have an extended partition
      storage_forward :extended_possible?, to: :extended_possible

      # @!method has_extended?
      #   @return [Boolean] whether an extended partition exists in the table
      storage_forward :has_extended?, to: :has_extended

      # @!method unused_partition_slots(align_policy = AlignPolicy::KEEP_END)
      #   Slots that could be used to create new partitions following the
      #   given align policy.
      #
      #   @param align_policy [AlignPolicy] policy to consider while looking for
      #     slots
      #   @return [Array<PartitionTables::PartitionSlot>]
      storage_forward :unused_partition_slots, as: "PartitionTables::PartitionSlot"

      # @!method partition_boot_flag_supported?
      #   @return [Boolean] whether the partitions in the table can have the
      #     boot flag.
      storage_forward :partition_boot_flag_supported?

      # @!method partition_legacy_boot_flag_supported?
      #   @return [Boolean] whether the partitions in the table can have the
      #     legacy boot flag.
      storage_forward :partition_legacy_boot_flag_supported?

      def inspect
        parts = partitions.map(&:inspect)
        slots = unused_partition_slots.map(&:to_s)
        "<PartitionTable #{self}[#{num_children}] #{parts}#{slots}>"
      end

      # The partition id depends on the partition table type. For example,
      # MSDOS partition tables use SWAP id for swap partitions, but DASD
      # partiton tables always need LINUX id.
      #
      # With this method, each partition table can define the partition id
      # it expects for each case.
      #
      # TODO: right now only :swap is considered.
      #
      # @param id_name [Symbol] a partition id name (e.g., :swap, :linux, :ntfs)
      # @return [PartitionId]
      def partition_id_for(id_name)
        case id_name
        when :swap
          PartitionId::SWAP
        else
          PartitionId::LINUX
        end
      end

    protected

      def types_for_is
        super << :partition_table
      end
    end
  end
end
