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
require "y2storage/partition_tables"

module Y2Storage
  # Base class for all the devices that can contain a partition table, like
  # disks or RAID devices
  #
  # This is a wrapper for Storage::Partitionable
  class Partitionable < BlkDevice
    wrap_class Storage::Partitionable, downcast_to: ["Disk", "Dasd", "DmRaid", "Md", "Multipath"]

    # @!attribute range
    #   Maximum number of partitions that the kernel can handle for the device.
    #   It used to be 16 for scsi and 64 for ide. Now it's 256 for most devices.
    #
    #   @return [Integer]
    storage_forward :range
    storage_forward :range=

    # @!method possible_partition_table_types
    #   Possible partition table types for the disk. The first entry is
    #     identical to the default partition table type for the disk
    #
    #   @return [Array<PartitionTables::Type>]
    storage_forward :possible_partition_table_types, as: "PartitionTables::Type"

    # @!method possible_partition_table_type
    #   Default partition table type as reported by libstorage
    #   @see #preferred_ptable_type
    #
    #   @return [PartitionTables::Type]
    storage_forward :default_partition_table_type, as: "PartitionTables::Type"
    private :default_partition_table_type

    # @!method create_partition_table(pt_type)
    #   Creates a partition table of the specified type for the device.
    #
    #   @raise [Storage::WrongNumberOfChildren] if the device is not empty (e.g.
    #     already contains a partition table or a filesystem).
    #   @raise [Storage::UnsupportedException] if the partition table type is
    #     not valid for the device. See {#possible_partition_table_types}
    #
    #   @param pt_type [PartitionTables::Type]
    #   @return [PartitionTables::Base] the concrete subclass will depend
    #     on pt_type
    storage_forward :create_partition_table, as: "PartitionTables::Base"

    # @!method partition_table
    #   @return [PartitionTables::Base] the concrete subclass will depend
    #     on the type
    storage_forward :partition_table, as: "PartitionTables::Base", check_with: :has_partition_table

    # @!method topology
    #   @return [Storage::Topology] Low-level object describing the device
    #     topology
    storage_forward :topology

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Partitionable>] all the partitionable devices in the given devicegraph,
    #     in no particular order
    storage_class_forward :all, as: "Partitionable"

    # Partitions in the device
    #
    # @return [Array<Partition>]
    def partitions
      partition_table ? partition_table.partitions : []
    end

    # Checks whether it contains a GUID partition table
    #
    # @return [Boolean]
    def gpt?
      return false unless partition_table
      partition_table.type.to_sym == :gpt
    end

    # Checks whether a name matches the device or any of its partitions
    #
    # @param name [String] device name
    # @return [Boolean]
    def name_or_partition?(name)
      return true if self.name == name

      partitions.any? { |part| part.name == name }
    end

    # Partitionable device matching the name or partition name
    #
    # @param devicegraph [Devicegraph] where to search
    # @param name [String] device name
    # @return [Partitionable] nil if there is no match
    def self.find_by_name_or_partition(devicegraph, name)
      all(devicegraph).detect { |dev| dev.name_or_partition?(name) }
    end

    # Partitions that can be used as EFI system partitions.
    #
    # Checks for the partition id to return all potential partitions.
    # Checking for content_info.efi? would only detect partitions that are
    # going to be effectively used.
    #
    # @return [Array<Partition>]
    def efi_partitions
      partitions_with_id(:esp)
    end

    # Partitions that can be used as PReP partition
    #
    # @return [Array<Partition>]
    def prep_partitions
      partitions_with_id(:prep)
    end

    # GRUB (gpt_bios) partitions
    #
    # @return [Array<Partition>]
    def grub_partitions
      partitions_with_id(:bios_boot)
    end

    # Partitions that can be used as swap space
    #
    # @return [Array<Partition>]
    def swap_partitions
      partitions_with_id(:swap)
    end

    # Partitions that can host part of a Linux system.
    #
    # @see PartitionId.linux_system_ids
    #
    # @return [Array<Partition>]
    def linux_system_partitions
      partitions_with_id(:linux_system)
    end

    # Partitions that could potentially contain a MS Windows installation
    #
    # @see ParitionId.windows_system_ids
    #
    # @return [Array<Partition>]
    def possible_windows_partitions
      partitions.select { |p| p.type.is?(:primary) && p.id.is?(:windows_system) }
    end

    # Size between MBR and first partition.
    #
    # @see PartitionTables::Msdos#mbr_gap
    #
    # This can return nil, meaning "gap not applicable" (e.g. it makes no sense
    # for the existing partition table) which is different from "no gap"
    # (i.e. a 0 bytes gap).
    #
    # @return [DiskSize, nil]
    def mbr_gap
      return nil unless partition_table
      return nil unless partition_table.respond_to?(:mbr_gap)
      partition_table.mbr_gap
    end

    # Free spaces inside the device
    #
    # @return [Array<FreeDiskSpace>]
    def free_spaces
      # Unused device
      return Array(FreeDiskSpace.new(self, region)) unless has_children?
      # Device in use, but with no partition table
      return [] if partition_table.nil?

      partition_table.unused_partition_slots.map do |slot|
        FreeDiskSpace.new(self, slot.region)
      end
    end

    # Executes the given block in a context in which the device always have a
    # partition table if possible, creating a temporary frozen one if needed.
    #
    # This allows any code to work under the assumption that a given device
    # has an empty partition table of the YaST default type, even if that
    # partition table is not yet created.
    #
    # @see preferred_ptable_type
    #
    # @example With a device that already has a partition table
    #   partitioned_disk.as_not_empty do
    #     partitioned_disk.partition_table # => returns the real partition table
    #   end
    #   partitioned_disk.partition_table # Still the same
    #
    # @example With a device not partitioned but formatted (or a PV)
    #   lvm_pv_disk.as_not_empty do
    #     lvm_pv_disk.partition_table # => raises DeviceHasWrongType
    #   end
    #   lvm_pv_disk.partition_table # Still the same
    #
    # @example With a completely empty device
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

    # Default partition table type for newly created partition tables
    #
    # This method is needed because YaST criteria does not necessarily match
    # the one followed by Storage::Disk#default_partition_table_type (which
    # defaults to MBR partition tables in many cases)
    #
    # @return [PartitionTables::Type]
    def preferred_ptable_type
      default_partition_table_type
    end

    # Returns the partition table, creating an empty one if needed.
    # @see #preferred_ptable_type
    #
    # @return [PartitionTable]
    def ensure_partition_table
      partition_table || create_partition_table(preferred_ptable_type)
    end

  protected

    # Find partitions that have a given (set of) partition id(s).
    #
    # @return [Array<Partition>}]
    def partitions_with_id(*ids)
      partitions.reject { |p| p.type.is?(:extended) }.select { |p| p.id.is?(*ids) }
    end
  end
end
