# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require "y2storage/proposal/autoinst_drive_planner"

module Y2Storage
  module Proposal
    # This class converts an AutoYaST specification into a Planned::Md in order
    # to set up a MD RAID.
    class AutoinstMdPlanner < AutoinstDrivePlanner
      # Returns a MD array according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the MD RAID
      # @return [Array<Planned::Md>] Planned MD RAID devices
      def planned_devices(drive)
        md =
          if drive.device == "/dev/md" || !drive.partition_table?
            non_partitioned_md(drive)
          else
            partitioned_md(drive)
          end

        if drive.disklabel
          md.ptable_type = Y2Storage::PartitionTables::Type.find(drive.disklabel)
        end

        Array(md)
      end

    private

      # Returns a non partitioned MD RAID
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the MD RAID
      # @return [Planned::Md]
      def non_partitioned_md(drive)
        md = Planned::Md.new(name: drive.name_for_md)
        part_section = drive.partitions.first
        device_config(md, part_section, drive)
        md.lvm_volume_group_name = part_section.lvm_group
        add_md_reuse(md, part_section) if part_section.create == false
        add_raid_options(md, part_section.raid_options)
        md
      end

      # Returns a partitioned MD RAID
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the MD RAID
      # @return [Planned::Md]
      def partitioned_md(drive)
        md = Planned::Md.new(name: drive.device)
        add_raid_options(md, drive.raid_options)
        md.partitions = drive.partitions.map do |part_section|
          plan_partition(md, drive, part_section)
        end
        md
      end

      # Adds RAID options to a planned RAID
      #
      # @param md [Planned::Md] Planned RAID
      # @param raid_options [AutoinstProfile::RaidOptionsSection] raid options section from
      #   the profile
      def add_raid_options(md, raid_options)
        md.md_level = raid_level_from(raid_options)
        return if raid_options.nil?
        md.name = raid_options.raid_name if raid_options.raid_name
        md.chunk_size = chunk_size_from_string(raid_options.chunk_size) if raid_options.chunk_size
        md.md_parity = MdParity.find(raid_options.parity_algorithm) if raid_options.parity_algorithm
      end

      # Sets 'reusing' attributes for a MD RAID
      #
      # @param md      [Planned::Md] Planned MD RAID
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_md_reuse(md, section)
        # TODO: fix when not using named raids
        md_to_reuse = devicegraph.md_raids.find { |m| m.name == md.name }
        if md_to_reuse.nil?
          issues_list.add(:missing_reusable_device, section)
          return
        end
        add_device_reuse(md, md_to_reuse.name, section)
      end

      # Parses the user specified chunk size
      #
      # @param string [String] User specified chunk size
      # @return [DiskSize]
      def chunk_size_from_string(string)
        string =~ /\D/ ? DiskSize.parse(string) : DiskSize.KB(string.to_i)
      end

      # XXX TO REMOVE

      # @return [DiskSize] Minimal partition size
      PARTITION_MIN_SIZE = DiskSize.B(1).freeze

      # Assign disk size according to AutoYaSt section
      #
      # @param disk        [Disk,Dasd]          Disk to put the partitions on
      # @param partition   [Planned::Partition] Partition to assign the size to
      # @param part_section   [AutoinstProfile::PartitionSection] Partition specification from AutoYaST
      def assign_size_to_md_partition(_md, partition, part_section)
        size_info = parse_size(part_section, PARTITION_MIN_SIZE, DiskSize.unlimited)

        if size_info.nil?
          issues_list.add(:invalid_value, part_section, :size)
          return false
        end

        if size_info.percentage
          partition.percent_size = size_info.percentage
        else
          partition.min_size = size_info.min
          partition.max_size = size_info.max
        end
        partition.weight = 1 if size_info.unlimited?

        true
      end

      # @param disk [Disk,Dasd] Disk to place the partitions on
      # @param drive [AutoinstProfile::DriveSection]
      # @param section [AutoinstProfile::PartitionSection]
      # @return [Planned::Partition,nil]
      def plan_partition(disk, drive, section)
        partition = Y2Storage::Planned::Partition.new(nil, nil)

        return unless assign_size_to_md_partition(disk, partition, section)

        partition.disk = disk.name
        partition.partition_id = section.id_for_partition
        partition.primary = section.partition_type == "primary" if section.partition_type
        partition.lvm_volume_group_name = section.lvm_group

        device_config(partition, section, drive)
        add_partition_reuse(partition, section) if section.create == false
        partition
      end

      # Given a user specified RAID type, it returns the RAID level
      #
      # @note If the raid_type is not specified or is invalid, falls back to RAID1.
      #
      # @param raid_type [String,nil] User defined RAID level
      # @return [Y2Storage::MdLevel] RAID level
      def raid_level_from(raid_options)
        return Y2Storage::MdLevel::RAID1 if raid_options.nil? || raid_options.raid_type.nil?
        MdLevel.find(raid_options.raid_type)
      rescue NameError
        issues_list.add(:invalid_value, raid_options.raid_type, :raid_type, "raid1")
        Y2Storage::MdLevel::RAID1
      end
    end
  end
end
