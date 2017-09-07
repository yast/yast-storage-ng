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
require "y2storage"
require "y2storage/filesystems/btrfs"
require "y2storage/subvol_specification"
require "y2partitioner/device_graphs"
require "y2partitioner/format_mount/options"

module Y2Partitioner
  module FormatMount
    # Base class for handle common format and mount operations
    class Base
      # params partition [Y2Storage::BlkDevice]
      # @param options [Options]
      def initialize(partition, options)
        @partition = partition
        @options = options
      end

      def apply_options!
        @partition.id = @options.partition_id
        apply_format_options!
        apply_mount_options!
      end

      # Performs selected format options over the device
      def apply_format_options!
        return false unless @options.encrypt || @options.format

        partition.remove_descendants

        if encrypt?
          @partition = partition.create_encryption("cr_#{@partition.basename}")
          partition.password = options.password
        end

        if format?
          filesystem = partition.create_filesystem(options.filesystem_type)
          if filesystem.supports_btrfs_subvolumes?
            default_path = Y2Storage::Filesystems::Btrfs.default_btrfs_subvolume_path
            filesystem.ensure_default_btrfs_subvolume(path: default_path)
          end
        end

        true
      end

      # Performs selected mount options over the device
      def apply_mount_options!
        return false if filesystem.nil?

        set_mount_point
        set_mount_options

        true
      end

    private

      attr_reader :partition

      attr_reader :options

      def set_mount_point
        return unless change_mount_point?

        subvolume_actions_before_set_mount_point
        filesystem.mount_point = mount? ? options.mount_point : ""
        subvolume_actions_after_set_mount_point
      end

      def set_mount_options
        return unless mount?

        filesystem.mount_by = options.mount_by
        filesystem.label = options.label if options.label
        filesystem.fstab_options = options.fstab_options
      end

      # Actions to perform before setting a new mount point
      #
      # When the filesystem is btrfs, the not probed subvolumes are deleted.
      def subvolume_actions_before_set_mount_point
        delete_not_probed_subvolumes if btrfs?
      end

      # Actions to perform after setting a new mount point
      #
      # When the filesystem is btrfs and root, default proposed subvolumes are added
      # in case they are not been probed.
      # When the filesystem is btrfs, the mount point of the resulting subvolumes is updated.
      # Shadowing control of btrfs subvolumes is always performed.
      def subvolume_actions_after_set_mount_point
        add_proposed_subvolumes if btrfs_root?
        update_mount_points if btrfs?
        Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(device_graph)
      end

      # Deletes not probed subvolumes
      def delete_not_probed_subvolumes
        loop do
          subvolume = find_not_probed_subvolume
          return if subvolume.nil?
          filesystem.delete_btrfs_subvolume(device_graph, subvolume.path)
        end
      end

      # Finds first not probed subvolume
      #
      # @note Top level and default subvolumes are not taken into account (see {#subvolumes}).
      #
      # @return [Y2Storage::BtrfsSubvolume, nil]
      def find_not_probed_subvolume
        device_graph = DeviceGraphs.instance.system
        subvolumes.detect { |s| !s.exists_in_devicegraph?(device_graph) }
      end

      # A proposed subvolume is added only when it does not exist in the filesystem and it
      # makes sense for the current architecture
      #
      # @see Y2Storage::Filesystems::Btrfs#add_btrfs_subvolumes
      def add_proposed_subvolumes
        specs = Y2Storage::SubvolSpecification.from_control_file
        specs = Y2Storage::SubvolSpecification.fallback_list if specs.nil? || specs.empty?

        filesystem.add_btrfs_subvolumes(specs)
      end

      # Updates subvolumes mount point
      #
      # @note Top level and default subvolumes are not taken into account (see {#subvolumes}).
      def update_mount_points
        fs = filesystem
        subvolumes.each do |subvolume|
          subvolume.mount_point = fs.btrfs_subvolume_mount_point(subvolume.path)
        end
      end

      def device_graph
        DeviceGraphs.instance.current
      end

      def format?
        options.format
      end

      def mount?
        options.mount
      end

      def encrypt?
        options.encrypt
      end

      def filesystem
        partition.filesystem
      end

      # Btrfs subvolumes without top level and default ones
      def subvolumes
        filesystem.btrfs_subvolumes.select do |subvolume|
          !subvolume.top_level? &&
            !subvolume.default_btrfs_subvolume?
        end
      end

      def change_mount_point?
        (!mount? && filesystem_has_mount_point?) || (mount? && filesystem_has_different_mount_point?)
      end

      def filesystem_has_mount_point?
        !filesystem.mount_point.nil? && !filesystem.mount_point.empty?
      end

      def filesystem_has_different_mount_point?
        filesystem.mount_point != options.mount_point
      end

      def btrfs?
        filesystem.supports_btrfs_subvolumes?
      end

      def btrfs_root?
        btrfs? && filesystem.root?
      end
    end
  end
end
