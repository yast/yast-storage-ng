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
  module PlannedDevices
    # Mixing for planned devices that can have an associated block filesystem.
    # @see PlannedDevices::Base
    module CanBeFormatted
      # @return [Filesystems::Type] the type of filesystem this device should
      #   get, like Filesystems::Type::BTRFS or Filesystems::Type::SWAP. A value of
      #   nil means the device will not be formatted.
      attr_accessor :filesystem_type

      # @return [String] label to enforce in the filesystem
      attr_accessor :label

      # @return [String] UUID to enforce in the filesystem
      attr_accessor :uuid

      # @return [Array<PlannedSubvolume>] Btrfs subvolumes
      attr_accessor :subvolumes

      # @return [String] Parent for all Btrfs subvolumes (typically "@")
      attr_accessor :default_subvolume

      # Initializations of the mixin, to be called from the class constructor.
      def initialize_can_be_formatted
      end

      # Creates a filesystem for the planned device on the specified real
      # BlkDevice object and set its mount point. Do nothing if #filesystem_type
      # is not set.
      #
      # @param blk_dev [BlkDevice]
      #
      # @return [Filesystems::BlkFilesystem] filesystem
      def create_filesystem(blk_dev)
        return nil unless filesystem_type
        filesystem = blk_dev.create_blk_filesystem(filesystem_type)
        filesystem.mountpoint = mount_point if mount_point && !mount_point.empty?
        filesystem.label = label if label
        filesystem.uuid = uuid if uuid
        filesystem
      end

      # Creates subvolumes on this device after the filesystem is created
      # if this is a btrfs root filesystem.
      #
      # @param filesystem [Filesystems::BlkFilesystem]
      # @param other_mount_points [Array<String>]
      #
      # @return nil
      #
      def create_subvolumes(filesystem, other_mount_points)
        return unless filesystem.supports_btrfs_subvolumes?
        return unless subvolumes?
        parent_subvol = get_parent_subvol(filesystem)
        parent_subvol.set_default_btrfs_subvolume
        prefix = filesystem.mountpoint
        prefix += "/" unless prefix == "/"
        subvolumes.each do |planned_subvol|
          # Notice that subvolumes not matching the current architecture are
          # already removed
          # TODO: this call to #shadows is probably missplaced here, but this
          # code is not covered by unit tests, so I will fix it in an upcoming
          # commit
          next if shadows?(prefix + planned_subvol.path, other_mount_points)
          planned_subvol.create_subvol(parent_subvol, @default_subvolume, prefix)
        end
        nil
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
    end
  end
end
