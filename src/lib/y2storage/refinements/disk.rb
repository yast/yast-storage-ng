#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "storage"
require "y2storage/free_disk_space"
require "y2storage/disk_size"

module Y2Storage
  module Refinements
    # Refinement for ::Storage::Disk with some commodity methods
    #
    # @deprecated All these methods are directly available in Y2Storage::Disk.
    #   This refinement should be deleted once Storage::Disk is not longer used
    #   directly in other modules.
    module Disk
      refine ::Storage::Disk do
        # Checks if it's an USB disk
        #
        # @return [Boolean]
        def usb?
          transport == ::Storage::Transport_USB
        end

        # Checks whether it contains a GUID partition table
        #
        # @return [Boolean]
        def gpt?
          partition_table.type == Storage::PtType_GPT
        rescue Storage::WrongNumberOfChildren
          # No partition table in the disk
          false
        end

        # Partitions contained in the disk
        #
        # @return [Array<::Storage::Partition>]
        def all_partitions
          has_partition_table ? partition_table.partitions.to_a : []
        end

        # Free spaces inside the disk
        #
        # @return [Array<FreeDiskSpace>]
        def free_spaces
          # Unused disk
          return Array(FreeDiskSpace.new(self, region)) unless has_children

          begin
            partition_table.unused_partition_slots.map do |slot|
              FreeDiskSpace.new(self, slot.region)
            end
          rescue Storage::DeviceHasWrongType
            # The disk is in use, but there is no partition table
            []
          end
        end

        # Minimal grain of the disk
        #
        # @return [DiskSize]
        def min_grain
          DiskSize.new(topology.minimal_grain)
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
          Storage::PtType_GPT
        end
      end
    end
  end
end
