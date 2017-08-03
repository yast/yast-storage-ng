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
require "y2storage/btrfs_subvolume"

module Y2Storage
  module Filesystems
    # A local filesystem.
    #
    # This a wrapper for Storage::BlkFilesystem
    class BlkFilesystem < Base
      wrap_class Storage::BlkFilesystem

      # @!method self.all(devicegraph)
      #   @param devicegraph [Devicegraph]
      #   @return [Array<Filesystems::BlkFilesystem>] all the block filesystems
      #     in the given devicegraph
      storage_class_forward :all, as: "Filesystems::BlkFilesystem"

      # @!method supports_label?
      #   @return [Boolean] whether the filesystem supports having a label
      storage_forward :supports_label?, to: :supports_label

      # @!method max_labelsize
      #   @return [Integer] max size of the label
      storage_forward :max_labelsize

      # @!attribute label
      #   @return [String] filesystem label
      storage_forward :label
      storage_forward :label=

      # @!method supports_uuid?
      #   @return [Boolean] whether the filesystem supports UUID
      storage_forward :supports_uuid?, to: :supports_uuid

      # @!attribute uuid
      #   @return [String] filesystem UUID
      storage_forward :uuid
      storage_forward :uuid=

      # @!attribute mkfs_options
      #   Options to use when calling mkfs during devicegraph commit (if the
      #   filesystem needs to be created in the system).
      #
      #   @return [String]
      storage_forward :mkfs_options
      storage_forward :mkfs_options=

      # @!attribute tune_options
      #   @return [String]
      storage_forward :tune_options
      storage_forward :tune_options=

      # @!method detect_content_info
      #   @return [Storage::ContentInfo]
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
        Storage.btrfs?(to_storage_value)
      end

      # Top level Btrfs subvolume
      #
      # Btrfs filesystems always have a top level subvolume, the mkfs.btrfs
      # command implicitly creates it, so does libstorage when creating the
      # data structures.
      #
      # The top level Btrfs subvolume always has ID 5.
      #
      # @return [BtrfsSubvolume] nil if it makes no sense for this filesystem
      def top_level_btrfs_subvolume
        return nil unless supports_btrfs_subvolumes?

        storage_subvol = Storage.to_btrfs(to_storage_value).top_level_btrfs_subvolume
        BtrfsSubvolume.new(storage_subvol)
      end

      # The default Btrfs subvolume (typically @).
      #
      # @note When a new Btrfs filesystem is created, a top level subvolume is added and
      #   initialized as default subvolume.
      #
      # @see #top_level_btrfs_subvolume
      #
      # @return [BtrfsSubvolume] nil if it makes no sense for this filesystem
      def default_btrfs_subvolume
        return nil unless supports_btrfs_subvolumes?

        storage_subvol = Storage.to_btrfs(to_storage_value).default_btrfs_subvolume
        BtrfsSubvolume.new(storage_subvol)
      end

      # Finds a subvolume by its path
      #
      # @param path [String] subvolume path
      # @return [BtrfsSubvolume, nil] nil if it does not find a subvolume with this path
      def find_btrfs_subvolume_by_path(path)
        return nil unless supports_btrfs_subvolumes?

        btrfs = Storage.to_btrfs(to_storage_value)
        storage_subvol = btrfs.find_btrfs_subvolume_by_path(path)
        BtrfsSubvolume.new(storage_subvol)
      rescue Storage::BtrfsSubvolumeNotFoundByPath
        nil
      end

      # Collection of Btrfs subvolumes of the device
      #
      # @return [Array<BtrfsSubvolumes>] empty if it makes no sense for this
      #   filesystem
      def btrfs_subvolumes
        return [] unless supports_btrfs_subvolumes?

        storage_subvols = Storage.to_btrfs(to_storage_value).btrfs_subvolumes
        storage_subvols.to_a.map { |vol| BtrfsSubvolume.new(vol) }
      end

      def default_btrfs_subvolume_path
        default_subvolume = default_btrfs_subvolume
        if default_subvolume.nil? || default_subvolume.top_level?
          DEFAULT_BTRFS_SUBVOLUME_PATH
        else
          default_subvolume.path
        end
      end

      def ensure_default_btrfs_subvolume
        subvolume = default_btrfs_subvolume

        if subvolume.nil? || subvolume.top_level?
          subvolume = btrfs_subvolumes.detect { |s| s.path == DEFAULT_BTRFS_SUBVOLUME_PATH }

          if subvolume.nil?
            subvolume = create_default_subvolume
          elsif !subvolume.default_btrfs_subvolume?
            subvolume.set_default_btrfs_subvolume
          end
        end

        subvolume
      end

      # @return [Boolean]
      def in_network?
        disks = ancestors.find_all { |d| d.is?(:disk) }
        disks.any?(&:in_network?)
      end

    protected

      DEFAULT_BTRFS_SUBVOLUME_PATH = "@"

      def create_default_subvolume
        top_level_subvolume = top_level_btrfs_subvolume
        subvolume = top_level_subvolume.create_btrfs_subvolume(DEFAULT_BTRFS_SUBVOLUME_PATH)
        subvolume.nocow = false
        subvolume.mountpoint = DEFAULT_BTRFS_SUBVOLUME_PATH
        subvolume.set_default_btrfs_subvolume
        subvolume
      end

      def types_for_is
        super << :blk_filesystem
      end
    end
  end
end
