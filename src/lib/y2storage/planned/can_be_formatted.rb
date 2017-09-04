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

      # @return [Array<SubvolSpecification>] Btrfs subvolume specifications
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
        @snapshots = false
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

      # Subvolume specifications that would be shadowed by any of the given planned devices.
      #
      # @param all_devices [Array<Planned::Device>] all the devices planned for the system.
      # @return [Array<SubvolSpecification>]
      def shadowed_subvolumes(all_devices)
        other_devices = all_devices - [self]
        other_mount_points = other_devices.map { |dev| mount_point_for(dev) }.compact
        subvolumes.select { |s| s.shadowed?(mount_point, other_mount_points) }
      end

      # @see #reformat
      #
      # @return [Boolean]
      def reformat?
        reformat
      end

      # Whether activation and configurion of Btrfs snapshots is wanted, if
      # possible, in the resulting filesystem.
      #
      # @see #snapshots?
      attr_writer :snapshots

      # Whether Btrfs snapshots should be activated in the resulting filesystem.
      #
      # @return [Boolean] true if snapshots are requested (see {#snapshots=}) and
      #   possible (so far, only for Btrfs root filesystems).
      def snapshots?
        @snapshots && btrfs? && mount_point == "/"
      end

    protected

      # Creates subvolumes in the previously created filesystem that is placed
      # in the final device.
      #
      # This also sets other Btrfs attributes, like the default subvolume or
      # Filesystems::Btrfs#configure_snapper
      #
      # @param filesystem [Filesystems::BlkFilesystem]
      def btrfs_setup(filesystem)
        filesystem.configure_snapper = snapshots? if filesystem.respond_to?(:configure_snapper=)

        return unless filesystem.supports_btrfs_subvolumes?
        # If a default subvolume is configured (in control.xml), create it; if not,
        # use the toplevel subvolume that is implicitly created by mkfs.btrfs.
        filesystem.ensure_default_btrfs_subvolume(path: @default_subvolume)
        return unless subvolumes?

        filesystem.add_btrfs_subvolumes(subvolumes)
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

      def mount_point_for(device)
        return nil unless device.respond_to?(:mount_point)
        return nil if device.mount_point.nil? || device.mount_point.empty?
        device.mount_point
      end
    end
  end
end
