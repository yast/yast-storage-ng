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
require "y2partitioner/format_mount/options"
require "y2partitioner/format_mount/root_subvolumes_builder"
require "y2storage/filesystems/btrfs"

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

      def apply_format_options!
        return false unless @options.encrypt || @options.format

        @partition.remove_descendants

        if @options.encrypt
          @partition = @partition.create_encryption("cr_#{@partition.basename}")
          @partition.password = @options.password
        end

        if format?
          filesystem = partition.create_filesystem(options.filesystem_type)
          create_default_btrfs_subvolume if filesystem.supports_btrfs_subvolumes?
        end

        true
      end

      def apply_mount_options!
        return false if filesystem.nil?

        set_mount_point
        set_mount_options

        true
      end

    private

      attr_reader :partition

      attr_reader :options

      def filesystem
        partition.filesystem
      end

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

      def subvolume_actions_before_set_mount_point
        if btrfs_root?
          # Filesystem was Btrfs for /, so remove current subvolumes
          RootSubvolumesBuilder.remove_subvolumes
        elsif has_mount_point?
          # Filesystem had a mount point, so create shadowed subvolumes again
          RootSubvolumesBuilder.add_subvolumes_shadowed_by(filesystem.mount_point)
        end
      end

      def subvolume_actions_after_set_mount_point
        if btrfs_root?
          # New btrfs for /, so create subvolumes
          RootSubvolumesBuilder.create_subvolumes
        elsif has_mount_point?
          # Filesystem has a new mount point, so remove shadowed subvolumes
          RootSubvolumesBuilder.remove_subvolumes_shadowed_by(filesystem.mount_point)
        end
      end

      def mount?
        options.mount
      end

      def change_mount_point?
        (!mount? && has_mount_point?) || (mount? && has_different_mount_point?)
      end

      def has_mount_point?
        !filesystem.mount_point.nil? && !filesystem.mount_point.empty?
      end

      def has_different_mount_point?
        filesystem.mount_point != options.mount_point
      end

      def btrfs_root?
        filesystem.supports_btrfs_subvolumes? && filesystem.root?
      end

      def create_default_btrfs_subvolume
        default_path = Y2Storage::Filesystems::Btrfs.default_btrfs_subvolume_path
        filesystem.ensure_default_btrfs_subvolume(path: default_path)
      end
    end
  end
end
