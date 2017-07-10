#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2017] SUSE LLC
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

module Y2Storage
  module Planned
    # Mixin for planned devices that can have an associated block filesystem.
    # @see Planned::Device
    module CanBeFormatted
      # @return [Filesystems::Type] the type of filesystem this device should
      #   get, like Filesystems::Type::BTRFS or Filesystems::Type::SWAP. A value of
      #   nil means the device will not be formatted.
      attr_accessor :filesystem_type

      # @return [String] label to enforce in the filesystem
      attr_accessor :label

      # @return [String] UUID to enforce in the filesystem
      attr_accessor :uuid

      # @return [Array<Planned::BtrfsSubvolume>] Btrfs subvolumes
      attr_accessor :subvolumes

      # @return [String] Parent for all Btrfs subvolumes (typically "@")
      attr_accessor :default_subvolume

      # @return [Boolean] Whether a reused device should be formatted. If set to
      #   false, the existing filesystem should be kept. Only relevant if
      #   #reuse? is true.
      attr_accessor :reformat

      # Initializations of the mixin, to be called from the class constructor.
      def initialize_can_be_formatted
        @subvolumes = []
        @reformat = false
      end

      # Creates a filesystem for the planned device on the specified real
      # BlkDevice object.
      #
      # This also sets all the filesystem attributes, like the mount point, and
      # creates the corresponding Btrfs subvolumes if needed.
      #
      # Do nothing if #filesystem_type is not set.
      #
      # FIXME: temporary API. It should be improved.
      #
      # @param blk_dev [BlkDevice]
      #
      # @return [Filesystems::BlkFilesystem] filesystem
      def format!(blk_dev)
        final_device = final_device!(blk_dev)
        return nil unless filesystem_type

        filesystem = final_device.create_blk_filesystem(filesystem_type)
        assign_mountpoint(filesystem)
        filesystem.label = label if label
        filesystem.uuid = uuid if uuid

        btrfs_setup(filesystem)

        filesystem
      end

      # Checks whether the filesystem type is Btrfs
      #
      # @return [Boolean]
      def btrfs?
        return false unless filesystem_type
        filesystem_type.is?(:btrfs)
      end

      # Checks whether the planned device has any subvolumes
      #
      # @return [Boolean]
      def subvolumes?
        btrfs? && !subvolumes.nil? && !subvolumes.empty?
      end

      # Removes from #subvolumes all the plannes subvolumes that would be
      # shadowed by another device mounted in any of the given mount points
      #
      # @param other_mount_points [Array<String>] mount points of the other
      #   devices in the filesystem
      def remove_shadowed_subvolumes!(other_mount_points)
        return if subvolumes.empty?
        self.subvolumes = subvolumes.reject { |subvol| subvol.shadowed?(other_mount_points) }
      end

      # @see #reformat
      #
      # @return [Boolean]
      def reformat?
        reformat
      end

    protected

      # Creates subvolumes in the previously created filesystem that is placed
      # in the final device.
      #
      # This also sets other Btrfs attributes, like the default subvolume.
      #
      # @param filesystem [Filesystems::BlkFilesystem]
      def btrfs_setup(filesystem)
        return unless filesystem.supports_btrfs_subvolumes?
        parent_subvol = get_parent_subvol(filesystem)
        parent_subvol.set_default_btrfs_subvolume

        return unless subvolumes?
        subvolumes.each do |planned_subvolume|
          planned_subvolume.create_subvol(parent_subvol, @default_subvolume)
        end
      end

      # Get the parent subvolume for all others on Btrfs 'filesystem':
      #
      # If a default subvolume is configured (in control.xml), create it; if not,
      # use the toplevel subvolume that is implicitly created by mkfs.btrfs.
      #
      # @param filesystem [Filesystems::BlkFilesystem]
      #
      # @return [BtrfsSubvolume]
      #
      def get_parent_subvol(filesystem)
        # The toplevel subvolume is implicitly created by mkfs.btrfs.
        # It does not have a name, and its subvolume ID is always 5.
        parent = filesystem.top_level_btrfs_subvolume
        if @default_subvolume && !@default_subvolume.empty?
          # If the "@" subvolume is specified in control.xml, this must be
          # created first, and it will be the parent of all the other
          # subvolumes. Otherwise, the toplevel subvolume is their direct parent.
          # Notice that this "@" subvolume does not show up in "btrfs subvolume
          # list".
          parent = parent.create_btrfs_subvolume(@default_subvolume)
        end
        parent
      end

      def reuse_device!(device)
        super

        if reformat
          format!(device)
        else
          filesystem = final_device!(device).filesystem
          assign_mountpoint(filesystem)
        end
      end

      def assign_mountpoint(filesystem)
        filesystem.mountpoint = mount_point if mount_point && !mount_point.empty?
      end
    end
  end
end
