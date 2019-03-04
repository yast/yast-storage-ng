#!/usr/bin/env ruby
#
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

require "y2storage/proposal_settings"
require "y2storage/proposal/autoinst_size_parser"
require "y2storage/volume_specification"

module Y2Storage
  module Proposal
    # This module offers a set of common methods that are used by AutoYaST planners.
    class AutoinstDrivePlanner
      # @!attribute [r] devicegraph
      #   @return [Devicegraph]
      # @!attribute [r] issues_list
      #
      attr_reader :devicegraph, :issues_list

      # Constructor
      #
      # @param devicegraph [Devicegraph] Devicegraph to be used as starting point
      # @param issues_list [AutoinstIssues::List] List of AutoYaST issues to register them
      def initialize(devicegraph, issues_list)
        @devicegraph = devicegraph
        @issues_list = issues_list
      end

      # Returns a planned volume group according to an AutoYaST specification
      #
      # @param _drive [AutoinstProfile::DriveSection] drive section
      # @return [Array] Array of planned devices
      def planned_devices(_drive)
        raise NotImplementedError
      end

    private

      # Set all the common attributes that are shared by any device defined by
      # a <partition> section of AutoYaST (i.e. a LV, MD or partition).
      #
      # @param device  [Planned::Device] Planned device
      # @param partition_section [AutoinstProfile::PartitionSection] AutoYaST
      #   specification of the concrete device
      # @param drive_section [AutoinstProfile::DriveSection] AutoYaST drive
      #   section containing the partition one
      def device_config(device, partition_section, drive_section)
        add_common_device_attrs(device, partition_section)
        add_snapshots(device, drive_section)
        add_subvolumes_attrs(device, partition_section)
      end

      # Set common devices attributes
      #
      # This method modifies the first argument setting crypt_key, crypt_fs,
      # mount, label, uuid and filesystem.
      #
      # @param device  [Planned::Device] Planned device
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_common_device_attrs(device, section)
        device.encryption_password = section.crypt_key if section.crypt_fs
        device.mount_point = section.mount
        device.label = section.label
        device.uuid = section.uuid
        device.filesystem_type = filesystem_for(section)
        device.mount_by = section.type_for_mountby
        device.mkfs_options = section.mkfs_options
        device.fstab_options = section.fstab_options
        device.read_only = read_only?(section.mount)
      end

      # Set device attributes related to snapshots
      #
      # This method modifies the first argument
      #
      # @param device  [Planned::Device] Planned device
      # @param drive_section [AutoinstProfile::DriveSection] AutoYaST specification
      def add_snapshots(device, drive_section)
        return unless device.respond_to?(:root?) && device.root?

        # Always try to enable snapshots if possible
        snapshots = true
        snapshots = false if drive_section.enable_snapshots == false

        device.snapshots = snapshots
      end

      # Set devices attributes related to Btrfs subvolumes
      #
      # This method modifies the first argument setting default_subvolume and
      # subvolumes.
      #
      # @param device  [Planned::Device] Planned device
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_subvolumes_attrs(device, section)
        return unless device.btrfs?

        defaults = subvolume_attrs_for(device.mount_point)

        device.default_subvolume = section.subvolumes_prefix || defaults[:subvolumes_prefix]

        device.subvolumes =
          if section.create_subvolumes
            section.subvolumes || defaults[:subvolumes] || []
          else
            []
          end
      end

      # Return the default subvolume attributes for a given mount point
      #
      # @param mount [String] Mount point
      # @return [Hash]
      def subvolume_attrs_for(mount)
        return {} if mount.nil?
        spec = VolumeSpecification.for(mount)
        return {} if spec.nil?
        { subvolumes_prefix: spec.btrfs_default_subvolume, subvolumes: spec.subvolumes }
      end

      # Return the filesystem type for a given section
      #
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      # @return [Filesystems::Type] Filesystem type
      def filesystem_for(section)
        return section.type_for_filesystem if section.type_for_filesystem
        return nil unless section.mount
        default_filesystem_for(section)
      end

      # Return the default filesystem type for a given section
      #
      # @param section [AutoinstProfile::PartitionSection]
      # @return [Filesystems::Type] Filesystem type
      def default_filesystem_for(section)
        spec = VolumeSpecification.for(section.mount)
        return spec.fs_type if spec && spec.fs_type
        section.mount == "swap" ? Filesystems::Type::SWAP : Filesystems::Type::BTRFS
      end

      # Determine whether the filesystem for the given mount point should be read-only
      #
      # @param mount_point [String] Filesystem mount point
      # @return [Boolean] true if it should be read-only; false otherwise.
      def read_only?(mount_point)
        return false unless mount_point
        spec = VolumeSpecification.for(mount_point)
        !!spec && spec.btrfs_read_only?
      end

      # @param planned_device [Planned::Partition,Planned::LvmLV,Planned::Md] Planned device
      # @param device         [Y2Storage::Device] Device to reuse
      # @param section        [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_device_reuse(planned_device, device, section)
        planned_device.reuse_name = device.is_a?(LvmVg) ? device.volume_group_name : device.name
        planned_device.reformat = !!section.format
        planned_device.resize = !!section.resize if planned_device.respond_to?(:resize=)
        check_reusable_filesystem(planned_device, device, section) if device.respond_to?(:filesystem)
      end

      # @param planned_device [Planned::Partition,Planned::LvmLV,Planned::Md] Planned device
      # @param device         [Y2Storage::Device] Device to reuse
      # @param section        [AutoinstProfile::PartitionSection] AutoYaST specification
      def check_reusable_filesystem(planned_device, device, section)
        return if planned_device.reformat || device.filesystem || planned_device.component?
        issues_list.add(:missing_reusable_filesystem, section)
      end

      # Parse the 'size' element
      #
      # @param section [AutoinstProfile::PartitionSection]
      # @param min     [DiskSize] Minimal size
      # @param max     [DiskSize] Maximal size
      # @see AutoinstSizeParser
      def parse_size(section, min, max)
        AutoinstSizeParser.new(proposal_settings).parse(section.size, section.mount, min, max)
      end

      # Instance of {ProposalSettings} based on the current product.
      #
      # Used to ensure consistency between the guided proposal and the AutoYaST
      # one when default values are used.
      #
      # @return [ProposalSettings]
      def proposal_settings
        @proposal_settings ||= ProposalSettings.new_for_current_product
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
        add_device_reuse(partition, partition_to_reuse, section)
        if !partition.reformat && !partition_to_reuse.filesystem && !partition.component?
          issues_list.add(:missing_reusable_filesystem, section)
        end
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

      # @param container [Planned::Disk,Planned::Dasd,Planned::Md] Device to place the partitions on
      # @param drive [AutoinstProfile::DriveSection]
      # @param section [AutoinstProfile::PartitionSection]
      # @return [Planned::Partition,nil]
      def plan_partition(container, drive, section)
        partition = Y2Storage::Planned::Partition.new(nil, nil)

        return unless assign_size_to_partition(partition, section)

        partition.disk = container.name
        partition.partition_id = section.id_for_partition
        partition.lvm_volume_group_name = section.lvm_group
        partition.raid_name = section.raid_name unless container.is_a?(Planned::Md)
        partition.primary = section.partition_type == "primary" if section.partition_type
        add_bcache_attrs(partition, section)

        device_config(partition, section, drive)
        add_partition_reuse(partition, section) if section.create == false
        partition
      end

      # Assign disk size according to AutoYaSt section
      #
      # @param partition   [Planned::Partition] Partition to assign the size to
      # @param part_section   [AutoinstProfile::PartitionSection] Partition specification from AutoYaST
      def assign_size_to_partition(partition, part_section)
        size_info = parse_size(part_section, PARTITION_MIN_SIZE, DiskSize.unlimited)

        if size_info.nil?
          issues_list.add(:invalid_value, part_section, :size)
          return false
        end

        partition.percent_size = size_info.percentage
        partition.min_size = size_info.min
        partition.max_size = size_info.max
        partition.weight = 1 if size_info.unlimited?
        true
      end

      # Adds Bcache specific attributes
      #
      # @param device  [Planned::Device] Planned device
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_bcache_attrs(device, section)
        device.bcache_backing_for = section.bcache_backing_for if section.bcache_backing_for
        device.bcache_caching_for = section.bcache_caching_for if section.bcache_caching_for
      end
    end
  end
end
