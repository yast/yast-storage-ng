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

require "yast"
require "y2storage/autoinst_profile/section_with_attributes"
require "y2storage/autoinst_profile/skip_list_section"
require "y2storage/autoinst_profile/partition_section"

Yast.import "Arch"

module Y2Storage
  module AutoinstProfile
    # Thin object oriented layer on top of a <drive> section of the
    # AutoYaST profile.
    #
    # More information can be found in the 'Partitioning' section of the AutoYaST documentation:
    # https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Partitioning
    # Check that document for details about the semantic of every attribute.
    class DriveSection < SectionWithAttributes
      def self.attributes
        [
          { name: :device },
          { name: :disklabel },
          { name: :enable_snapshots },
          { name: :imsmdriver },
          { name: :initialize_attr, xml_name: :initialize },
          { name: :keep_unknown_lv },
          { name: :lvm2 },
          { name: :is_lvm_vg },
          { name: :partitions },
          { name: :pesize },
          { name: :type },
          { name: :use },
          { name: :skip_list },
          { name: :raid_options }
        ]
      end

      define_attr_accessors

      # @!attribute device
      #   @return [String] device name

      # @!attribute disklabel
      #   @return [String] partition table type

      # @!attribute enable_snapshots
      #   @return [Boolean] undocumented attribute

      # @!attribute imsmdriver
      #   @return [Symbol] undocumented attribute

      # @!attribute initialize_attr
      #   @return [Boolean] value of the 'initialize' attribute in the profile
      #     (reserved name in Ruby). Whether the partition table must be wiped
      #     out at the beginning of the AutoYaST process.

      # @!attribute keep_unknown_lv
      #   @return [Boolean] whether the existing logical volumes should be
      #   kept. Only makes sense if #type is :CT_LVM and there is a volume group
      #   to reuse.

      # @!attribute lvm2
      #   @return [Boolean] undocumented attribute

      # @!attribute is_lvm_vg
      #   @return [Boolean] undocumented attribute

      # @!attribute partitions
      #   @return [Array<PartitionSection>] a list of <partition> entries

      # @!attribute pesize
      #   @return [String] size of the LVM PE

      # @!attribute type
      #   @return [Symbol] :CT_DISK or :CT_LVM

      # @!attribute use
      #   @return [String,Array<Integer>] strategy AutoYaST will use to partition the disk

      # @!attribute skip_list
      #   @return [Array<SkipListSection] collection of <skip_list> entries

      # @!attribute raid_options
      #   @return [RaidOptionsSection] RAID options
      #   @see RaidOptionsSection

      # Constructor
      #
      # @param parent [#parent,#section_name] parent section
      def initialize(parent = nil)
        @parent = parent
        @partitions = []
        @skip_list = SkipListSection.new([])
      end

      # Method used by {.new_from_hashes} to populate the attributes.
      #
      # It only enforces default values for #type (:CT_DISK) and #use ("all")
      # since the {AutoinstProposal} algorithm relies on them.
      #
      # @param hash [Hash] see {.new_from_hashes}
      def init_from_hashes(hash)
        super
        @type ||= default_type_for(hash)
        @use = use_value_from_string(hash["use"]) if hash["use"]
        @partitions = partitions_from_hash(hash)
        @skip_list = SkipListSection.new_from_hashes(hash.fetch("skip_list", []), self)
        if hash["raid_options"]
          @raid_options = RaidOptionsSection.new_from_hashes(hash["raid_options"], self)
          @raid_options.raid_name = nil # This element is not supported here
        end
      end

      def default_type_for(hash)
        return :CT_MD if hash["device"].to_s.start_with?("/dev/md")
        :CT_DISK
      end

      # Clones a drive into an AutoYaST profile section by creating an instance
      # of this class from the information in a block device.
      #
      # @see PartitioningSection.new_from_storage for more details
      #
      # @param device [BlkDevice] a block device that can be cloned into a
      #   <drive> section, like a disk, a DASD or an LVM volume group.
      # @return [DriveSection]
      def self.new_from_storage(device)
        result = new
        # So far, only disks (and DASD) are supported
        initialized = result.init_from_device(device)
        initialized ? result : nil
      end

      # Method used by {.new_from_storage} to populate the attributes when
      # cloning a device.
      #
      # As usual, it keeps the behavior of the old clone functionality, check
      # the implementation of this class for details.
      #
      # @param device [BlkDevice] a block device that can be cloned into a
      #   <drive> section, like a disk, a DASD or an LVM volume group.
      # @return [Boolean] if attributes were successfully read; false otherwise.
      def init_from_device(device)
        if device.is?(:software_raid)
          init_from_md(device)
        elsif device.is?(:lvm_vg)
          init_from_vg(device)
        else
          init_from_disk(device)
        end
      end

      # Device name to be used for the real MD device
      #
      # @see PartitionSection#name_for_md for details
      #
      # @return [String] MD RAID device name
      def name_for_md
        return partitions.first.name_for_md if device == "/dev/md"
        device
      end

      # Content of the section in the format used by the AutoYaST modules
      #
      # @return [Hash] each element of the hash corresponds to one of the
      #     attributes defined in the section. Blank attributes are not
      #     included.
      def to_hashes
        hash = super
        hash["use"] = use.join(",") if use.is_a?(Array)
        hash
      end

      # Return section name
      #
      # @return [String] "drives"
      def section_name
        "drives"
      end

      # @return [String] disklabel value which indicates that no partition table is wanted.
      NO_PARTITION_TABLE = "none".freeze

      # Determine whether the partition table is explicitly not wanted
      #
      # @note When the disklabel is set to 'none', a partition table should not be created.
      #   For backward compatibility reasons, setting partition_nr to 0 has the same effect.
      #   When no disklabel is set, this method returns false.
#
      # @return [Boolean] Returns true when a partition table is wanted; false otherwise.
      def unwanted_partitions?
        disklabel == NO_PARTITION_TABLE || partitions.any? { |i| i.partition_nr == 0 }
      end

      # Determines whether a partition table is explicitly wanted
      #
      # @note When the disklabel is set to some value which does not disable partitions,
      #   a partition table is expected. When no disklabel is set, this method returns
      #   false.
      #
      # @see unwanted_partitions?
      # @return [Boolean] Returns true when a partition table is wanted; false otherwise.
      def wanted_partitions?
        !(disklabel.nil? || unwanted_partitions?)
      end

      # Returns the partition which contains the configuration for the whole disk
      #
      # @return [PartitionSection,nil] Partition section for the whole disk; it returns
      #   nil if the device will use a partition table.
      #
      # @see #partition_table?
      def master_partition
        return unless unwanted_partitions?
        partitions.find { |i| i.partition_nr == 0 } || partitions.first
      end

    protected

      # Method used by {.new_from_storage} to populate the attributes when
      # cloning a disk or DASD device.
      #
      # As usual, it keeps the behavior of the old clone functionality, check
      # the implementation of this class for details.
      #
      # @param disk [Y2Storage::Disk, Y2Storage::Dasd] Disk
      # @return [Boolean]
      def init_from_disk(disk)
        return false unless used?(disk)

        @type = :CT_DISK
        # s390 prefers udev by-path device names (bsc#591603)
        @device = Yast::Arch.s390 ? disk.udev_full_paths.first : disk.name
        # if disk.udev_full_paths.first is nil go for disk.name anyway
        @device ||= disk.name
        @disklabel = disklabel_from_disk(disk)

        @partitions = partitions_from_disk(disk)
        return false if @partitions.empty?

        @enable_snapshots = enabled_snapshots?(disk.partitions.map(&:filesystem))
        @partitions.each { |i| i.create = false } if reuse_partitions?(disk)

        # Same logic followed by the old exporter
        @use =
          if disk.partitions.any? { |i| windows?(i) }
            @partitions.map(&:partition_nr)
          else
            "all"
          end

        true
      end

      # Method used by {.new_from_storage} to populate the attributes when
      # cloning a volume group.
      #
      # @param vg [Y2Storage::LvmVg] Volume group
      # @return [Boolean]
      def init_from_vg(vg)
        return false if vg.lvm_lvs.empty?

        @type = :CT_LVM
        @device = vg.name

        @partitions = partitions_from_collection(vg.lvm_lvs)
        return false if @partitions.empty?

        @enable_snapshots = enabled_snapshots?(vg.lvm_lvs.map(&:filesystem))
        @pesize = vg.extent_size.to_i.to_s
        true
      end

      # Method used by {.new_from_storage} to populate the attributes when
      # cloning a MD RAID.
      #
      # @param md [Y2Storage::Md] RAID
      # @return [Boolean]
      def init_from_md(md)
        @type = :CT_MD
        @device = md.name
        collection =
          if md.filesystem
            [md]
          else
            md.partitions
          end
        @partitions = partitions_from_collection(collection)
        @enable_snapshots = enabled_snapshots?(collection.map(&:filesystem).compact)
        @raid_options = RaidOptionsSection.new_from_storage(md)
        @raid_options.raid_name = nil if @raid_options # This element is not supported here
        true
      end

      def partitions_from_hash(hash)
        return [] unless hash["partitions"]
        hash["partitions"].map { |part| PartitionSection.new_from_hashes(part, self) }
      end

      # Return the partition sections for the given disk
      #
      # @note If there is no partition table, an array containing a single section
      #   (which represents the whole disk) will be returned.
      #
      # @return [Array<AutoinstProfile::PartitionSection>] List of partition sections
      def partitions_from_disk(disk)
        if disk.partition_table
          collection = disk.partitions.reject { |p| skip_partition?(p) }
          partitions_from_collection(collection.sort_by(&:number))
        else
          [PartitionSection.new_from_storage(disk)]
        end
      end

      def partitions_from_collection(collection)
        collection.each_with_object([]) do |storage_partition, result|
          partition = PartitionSection.new_from_storage(storage_partition)
          next unless partition
          result << partition
        end
      end

      # Whether AutoYaST considers a partition to be part of a Windows
      # installation and not directly relevant for the system being
      # cloned.
      #
      # NOTE: to ensure backward compatibility, this method implements the
      # logic present in the old AutoYaST exporter that used to live in
      # AutoinstPartPlan#ReadHelper.
      # https://github.com/yast/yast-autoinstallation/blob/47c24fb98e074f5b6432f3a4f8b9421362ee29cc/src/modules/AutoinstPartPlan.rb#L345
      # Check the comments in the code to know more about what is checked
      # and why.
      #
      # @param partition [Y2Storage::Partition]
      # @return [Boolean]
      def windows?(partition)
        # Only partitions with a typical Windows ID are considered
        return false unless partition.id.is?(:windows_system)

        # If the partition is mounted in /boot*, then it doesn't fully
        # belong to Windows, it's also relevant for the current system
        if partition.filesystem_mountpoint && partition.filesystem_mountpoint.include?("/boot")
          return false
        end

        # Surprinsingly enough, partitions with the boot flag are discarded
        # as Windows partitions (btw, we expect better compatibility checking
        # only for the corresponding flag on MSDOS partition tables, leaving
        # out Partition#legacy_boot?, although we cannot be sure).
        #
        # This extra criteria of checking the boot flag was introduced in
        # commit 795a18a795cd45d7e5f4d (January 2017) in order to fix
        # bsc#192342. The PPC bootloader was switching the id of the partition
        # from id 0x41 (PReP) to id 0x06 (FAT16) and as a result the AutoYaST
        # exporter was ignoring the partition (considering it to be a Windows
        # partition). Very likely, the intention of the fix was just to stop
        # considering such FAT16+boot partitions as part of Windows.
        # Unfortunately, the introduced fix affected all Windows-related ids,
        # not only FAT16.
        # That side effect has been there for 10+ years, so let's keep it.
        !partition.boot?
      end

      # Whether a given partition should be ignored when cloning the devicegraph
      # into a profile section.
      #
      # @return [Boolean] true if the partition is extended or considered to be
      #   a Windows system (see #windows?)
      def skip_partition?(partition)
        partition.type.is?(:extended) || windows?(partition)
      end

      # Whether all partitions in the drive should have "create" set to false
      # (so no new partitions will be actually created in the target system).
      #
      # NOTE: This implements logic that was present in the old exporter and
      # returns true if there is a Windows partition (see {#windows?}) that is
      # placed in the disk after any non-Windows partition.
      #
      # @param disk [Y2Storage::Partitionable]
      # @return [Boolean]
      def reuse_partitions?(disk)
        linux_already_found = false
        disk.partitions.sort_by { |i| i.region.start }.each do |part|
          next if part.type.is?(:extended)

          if windows?(part)
            return true if linux_already_found
          else
            linux_already_found = true
          end
        end
        false
      end

      # Return value for the "use" element
      #
      # If the given string is a comma separated list of numbers, it will
      # return an array containing those numbers. Otherwise, the original
      # value will be returned.
      #
      # @return [String,Array<Integer>]
      def use_value_from_string(use)
        return use unless use =~ /(\d+,?)+/
        use.split(",").select { |n| n =~ /\d+/ }.map(&:to_i)
      end

      # Determine whether snapshots are enabled
      #
      # Currently AutoYaST does not support enabling/disabling snapshots
      # for a partition but for the whole disk/volume group.
      #
      # @param filesystems [Array<Y2Storage::Filesystem>] Filesystems to evaluate
      # @return [Boolean] true if snapshots are enabled
      def enabled_snapshots?(filesystems)
        filesystems.any? { |f| f.respond_to?(:snapshots?) && f.snapshots? }
      end

      # Determine whether the disk is used or not
      #
      # @param disk [Array<Y2Storage::Disk,Y2Storage::Dasd>] Disk to check whether it is used
      # @return [Boolean] true if the disk is being used
      def used?(disk)
        !(disk.partitions.empty? && disk.component_of.empty?)
      end

      # Return the disklabel value for the given disk
      #
      # @note When no partition table is wanted, the value 'none' will be used.
      #
      # @param disk [Array<Y2Storage::Disk,Y2Storage::Dasd>] Disk to check get the disklabel from
      # @return [String] Disklabel value
      def disklabel_from_disk(disk)
        disk.partition_table ? disk.partition_table.type.to_s : NO_PARTITION_TABLE
      end
    end
  end
end
