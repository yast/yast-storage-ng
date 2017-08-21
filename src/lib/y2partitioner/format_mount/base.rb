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
        delete_new_subvolumes if btrfs?
      end

      # Actions to perform after setting a new mount point
      #
      # When the filesystem is btrfs and root, default proposed subvolumes are added
      # in case they are not been probed.
      # When the filesystem is btrfs, the mount point of the resulting subvolumes is updated.
      # Shadowing control of root btrfs subvolumes is always performed.
      def subvolume_actions_after_set_mount_point
        add_proposed_subvolumes if btrfs_root?
        update_mount_points if btrfs?
        Y2Storage::Filesystems::Btrfs.refresh_root_subvolumes_shadowing(devicegraph)
      end

      def delete_new_subvolumes
        new_subvolumes.each { |s| filesystem.delete_btrfs_subvolume(devicegraph, s.path) }
      end

      # Subvolumes that have not been probed
      # @return [Array<Y2Storage::BtrfsSubvolume>]
      def new_subvolumes
        devicegraph = DeviceGraphs.instance.system
        filesystem.btrfs_subvolumes.select { |s| !s.exists_in_devicegraph?(devicegraph) }
      end

      # Only proposed subvolumes that have not been already probed are added
      def add_proposed_subvolumes
        specs = Y2Storage::SubvolSpecification.for_current_product

        specs.each do |spec|
          next if exist_subvolume?(spec)
          add_proposed_subvolume(spec)
        end
      end

      def exist_subvolume?(spec)
        path = filesystem.btrfs_subvolume_path(spec.path)
        !filesystem.find_btrfs_subvolume_by_path(path).nil?
      end

      def add_proposed_subvolume(spec)
        path = filesystem.btrfs_subvolume_path(spec.path)
        nocow = !spec.copy_on_write
        subvolume = filesystem.create_btrfs_subvolume(path, nocow)
        # Proposed subvolumes can be automatically deleted when they are shadowed
        subvolume.can_be_auto_deleted = true
      end

      def update_mount_points
        fs = filesystem
        fs.btrfs_subvolumes.each do |subvolume|
          subvolume.mount_point = fs.btrfs_subvolume_mount_point(subvolume.path)
        end
      end

      def devicegraph
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
