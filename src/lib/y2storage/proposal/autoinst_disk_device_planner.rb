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
    # This class converts an AutoYaST specification into a set of planned block devices
    # ({Y2Storage::Planned::Partition} and {Y2Storage::Planned::StrayBlkDevice}).
    class AutoinstDiskDevicePlanner < AutoinstDrivePlanner
      # Returns an array of planned partitions for a given disk or the disk
      # itself if there are no partitions planned
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the layout for the disk
      # @return [Array<Planned::Partition, Planned::StrayBlkDevice>] List of planned partitions or disks
      def planned_devices(drive)
        disk = BlkDevice.find_by_name(devicegraph, drive.device)
        if disk
          planned_for_disk(disk, drive)
        else
          planned_for_stray_devices(drive)
        end
      end

    private

      # Returns an array of planned partitions for a given disk or the disk
      # itself if there are no partitions planned
      #
      # @param disk [Disk,Dasd] Disk to place the partitions on
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the layout for the disk
      # @return [Array<Planned::Disk, Planned::StrayBlkDevice>] List of planned partitions or disks
      def planned_for_disk(disk, drive)
        # partition 0: use the entire device
        partition_zero = drive.partitions.find { |p| p.partition_nr == 0 }
        result = if partition_zero
          planned_for_full_disk(drive, partition_zero)
        else
          planned_for_partitions(disk, drive)
        end

        Array(result)
      end

      # Returns disk to be used without partitions.
      #
      # @note This is not quite what #planned_for_stray_devices is for:
      #   #planned_for_full_disk creates a single entry for the full disk while
      #   #planned_for_stray_devices creates full disk entries for each
      #   partition.
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the layout for the disk
      # @param part [AutoinstProfile::PartitionSection] partition section with
      #   elements to apply to the full disk
      # @return [Array<Planned::Disk>] List containing planned disk
      #
      # @note The part argument is used when we emulate the sle12 behavior to
      #   have partition 0 mean the full disk.
      def planned_for_full_disk(drive, part)
        planned_disk = Y2Storage::Planned::Disk.new
        device_config(planned_disk, part, drive)
        planned_disk.lvm_volume_group_name = part.lvm_group
        add_device_reuse(planned_disk, drive.device, part)

        [planned_disk]
      end

      # Returns an array of planned partitions for a given disk
      #
      # @param disk [Disk,Dasd] Disk to place the partitions on
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the layout for the disk
      # @return [Planned::Disk] List of planned partitions
      def planned_for_partitions(disk, drive)
        planned_disk = Y2Storage::Planned::Disk.new

        planned_disk.partitions = drive.partitions.each_with_object([]).each do |section, memo|
          planned_partition = plan_partition(disk, drive, section)
          memo << planned_partition if planned_partition
        end

        planned_disk
      end

      # @todo The `drive` is needed because we need to check later whether the
      #   `enable_snapshots` is set or not. That's a consequence of having that
      #   element in the wrong place.
      #
      # @param disk [Disk,Dasd] Disk to place the partitions on
      # @param drive [AutoinstProfile::DriveSection]
      # @param section [AutoinstProfile::PartitionSection]
      # @return [Planned::Partition,nil]
      def plan_partition(disk, drive, section)
        # TODO: fix Planned::Partition.initialize
        partition = Y2Storage::Planned::Partition.new(nil, nil)

        return unless assign_size_to_partition(disk, partition, section)

        # TODO: partition.bootable is not in the AutoYaST profile. Check if
        # there's some logic to set it in the old code.

        partition.disk = disk.name
        partition.partition_id = section.id_for_partition
        partition.lvm_volume_group_name = section.lvm_group
        partition.raid_name = section.raid_name
        partition.primary = section.partition_type == "primary" if section.partition_type

        device_config(partition, section, drive)
        add_partition_reuse(partition, section) if section.create == false
        partition
      end

      # Returns an array of planned Xen partitions according to a <drive>
      # section which groups virtual partitions with a similar name (e.g. a
      # "/dev/xvda" section describing "/dev/xvda1" and "/dev/xvda2").
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   a set of stray block devices (Xen virtual partitions)
      # @return [Array<Planned::StrayBlkDevice>] List of planned devices
      def planned_for_stray_devices(drive)
        result = []
        drive.partitions.each do |section|
          # Since this drive section was included in the drives map, we can be
          # sure that all partitions include a valid partition_nr
          # (see {AutoinstDrivesMap#stray_devices_group?}).
          name = drive.device + section.partition_nr.to_s
          stray = Y2Storage::Planned::StrayBlkDevice.new
          device_config(stray, section, drive)

          # Just for symmetry respect partitions, try to infer the filesystem
          # type if it's omitted in the profile for devices that are going to be
          # re-formatted but not mounted, so there is no reasonable way to infer
          # the appropiate filesystem type based on the mount path (bsc#1060637).
          if stray.filesystem_type.nil?
            device_to_use = devicegraph.stray_blk_devices.find { |d| d.name == name }
            stray.filesystem_type = device_to_use.filesystem_type if device_to_use
          end

          add_device_reuse(stray, name, section)

          result << stray
        end

        result
      end

      # Set 'reusing' attributes for a partition
      #
      # This method modifies the first argument setting the values related to
      # reusing a partition (reuse and format).
      #
      # @param partition [Planned::Partition] Planned partition
      # @param section   [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_partition_reuse(partition, section)
        partition_to_reuse = find_partition_to_reuse(partition, section)
        return unless partition_to_reuse
        partition.filesystem_type ||= partition_to_reuse.filesystem_type
        add_device_reuse(partition, partition_to_reuse.name, section)
      end

      # @param partition    [Planned::Partition] Planned partition
      # @param part_section [AutoinstProfile::PartitionSection] Partition specification
      #   from AutoYaST
      def find_partition_to_reuse(partition, part_section)
        disk = devicegraph.find_by_name(partition.disk)
        device =
          if part_section.partition_nr
            disk.partitions.find { |i| i.number == part_section.partition_nr }
          elsif part_section.label
            disk.partitions.find { |i| i.filesystem_label == part_section.label }
          else
            issues_list.add(:missing_reuse_info, part_section)
            nil
          end

        issues_list.add(:missing_reusable_device, part_section) unless device
        device
      end

      # @return [DiskSize] Minimal partition size
      PARTITION_MIN_SIZE = DiskSize.B(1).freeze

      # Assign disk size according to AutoYaSt section
      #
      # @param disk        [Disk,Dasd]          Disk to put the partitions on
      # @param partition   [Planned::Partition] Partition to assign the size to
      # @param part_section   [AutoinstProfile::PartitionSection] Partition specification from AutoYaST
      def assign_size_to_partition(disk, partition, part_section)
        size_info = parse_size(part_section, PARTITION_MIN_SIZE, disk.size)

        if size_info.nil?
          issues_list.add(:invalid_value, part_section, :size)
          return false
        end

        partition.min_size = size_info.min
        partition.max_size = size_info.max
        partition.weight = 1 if size_info.unlimited?
        true
      end
    end
  end
end
