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
require "y2storage/partitionable"
require "y2storage/free_disk_space"
require "y2storage/data_transport"

module Y2Storage
  # A physical disk device
  #
  # This is a wrapper for Storage::Disk
  class Disk < Partitionable
    wrap_class Storage::Disk

    # @!method rotational?
    #   @return [Boolean] whether this is a rotational device
    storage_forward :rotational?, to: :rotational

    # @!method transport
    #   @return [DataTransport]
    storage_forward :transport, as: "DataTransport"

    # @!method self.create(devicegraph, name, region_or_size = nil)
    #   @param devicegraph [Devicegraph]
    #   @param name [String]
    #   @param region_or_size [Region, DiskSize]
    #   @return [Disk]
    storage_class_forward :create, as: "Disk"

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Disk>] all the disks in the given devicegraph
    storage_class_forward :all, as: "Disk"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String] kernel-style device name (e.g. "/dev/sda")
    #   @return [Disk] nil if there is no such disk
    storage_class_forward :find_by_name, as: "Disk"

    # Free spaces inside the disk
    #
    # @return [Array<FreeDiskSpace>]
    def free_spaces
      # Unused disk
      return Array(FreeDiskSpace.new(self, region.to_storage_value)) unless has_children?
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

    # Executes the given block in a context in which the disk always have a
    # partition table if possible, creating a temporary frozen one if needed.
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
      if !has_children?
        fake_ptable = create_partition_table(preferred_ptable_type)
        fake_ptable.freeze
      end

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

  protected

    def types_for_is
      super << :disk
    end
  end
end
