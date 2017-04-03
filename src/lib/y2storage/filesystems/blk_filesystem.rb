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

require "y2storage/storage_class_wrapper"
require "y2storage/filesystems/base"

module Y2Storage
  module Filesystems
    # A local filesystem.
    #
    # This a wrapper for Storage::BlkFilesystem
    class BlkFilesystem < Base
      wrap_class Storage::BlkFilesystem

      storage_class_forward :all, as: "Filesystems::BlkFilesystem"

      storage_forward :supports_label?, to: :supports_label
      storage_forward :max_labelsize
      storage_forward :label
      storage_forward :label=

      storage_forward :supports_uuid?, to: :supports_uuid
      storage_forward :uuid
      storage_forward :uuid=

      storage_forward :mkfs_options
      storage_forward :mkfs_options=
      storage_forward :tune_options
      storage_forward :tune_options=
      storage_forward :detect_content_info

      # @!method blk_devices
      #   Formatted block devices. It returns the block devices directly hosting
      #   the filesystem. That is, for encrypted filesystems it returns the
      #   encryption devices.
      #
      #   In most cases, this collection will contain just one element, since
      #   most filesystems sit on top of just one block device.
      #   But that's not necessarily true for Btrfs, see
      #   https://btrfs.wiki.kernel.org/index.php/Using_Btrfs_with_Multiple_Devices
      #
      #   @return [Array<BlkDevice>]
      storage_forward :blk_devices, as: "BlkDevice"

      # Raw (non encrypted) version of the formatted devices. If the filesystem
      # is not encrypted, it returns the same collection that #blk_devices,
      # otherwise it returns the original devices instead of the encryption
      # ones.
      #
      # @return [Array<BlkDevice>]
      def plain_blk_devices
        blk_devices.map(&:plain_device)
      end

      # Checks whether the filesystem has the capability of hosting Btrfs
      # subvolumes
      def supports_btrfs_subvolumes?
        Storage.is_btrfs(to_storage_value)
      end

      # Top level Btrfs subvolume
      #
      # @return [BtrfsSubvolume] nil if the subvolume is not defined or makes no
      #   sense for this filesystem
      def top_level_btrfs_subvolume
        return nil unless supports_btrfs_subvolumes?

        # FIXME: not sure if this will work in all cases. Revisit when the
        # Storage API for Btrfs is stable.
        # It is possible for a Btrfs to not have a top level volume? If so,
        # what it will happen here? An exception? If so, which one?
        storage_subvol = Storage.to_btrfs(to_storage_value).top_level_btrfs_subvolume
        return nil unless storage_subvol

        BtrfsSubvolume.new(storage_subvol)
      end

      # Collection of Btrfs subvolumes of the device
      #
      # @return [Array<BtrfsSubvolumes>] empty if it makes no sense for this
      #   filesystem
      def btrfs_subvolumes
        return [] unless supports_btrfs_subvolumes?

        storage_subvols = Storage.to_btrfs(to_storage_value).btrfs_subvolumes
        storage_subvols.map { |vol| BtrfsSubvolume.new(vol) }
      end

    protected

      def types_for_is
        super << :blk_filesystem
      end
    end
  end
end
