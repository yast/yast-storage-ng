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

    protected

      def types_for_is
        super << :partition_table
      end
    end
  end
end
