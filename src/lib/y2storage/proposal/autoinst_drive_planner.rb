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

      # @param device  [Planned::Partition,Planned::LvmLV] Planned device
      # @param name    [String] Name of the device to reuse
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_device_reuse(device, name, section)
        device.reuse_name = name
        device.reformat = !!section.format
        device.resize = !!section.resize if device.respond_to?(:resize=)
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
    end
  end
end
