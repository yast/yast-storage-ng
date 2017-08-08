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
require "y2storage/filesystems/blk_filesystem"
require "y2storage/btrfs_subvolume"

Yast.import "ProductFeatures"

module Y2Storage
  module Filesystems
    # This is a wrapper for Storage::Btrfs
    class Btrfs < BlkFilesystem
      wrap_class Storage::Btrfs

      # @!method top_level_btrfs_subvolume
      #   Top level Btrfs subvolume
      #
      #   Btrfs filesystems always have a top level subvolume, the mkfs.btrfs
      #   command implicitly creates it, so does libstorage when creating the
      #   data structures.
      #
      #   The top level Btrfs subvolume always has ID 5.
      #
      #   @return [BtrfsSubvolume]
      storage_forward :top_level_btrfs_subvolume, as: "BtrfsSubvolume"

      # @!method default_btrfs_subvolume
      #   The default Btrfs subvolume (typically @).
      #
      #   @note When a new Btrfs filesystem is created, a top level subvolume is added and
      #   initialized as default subvolume.
      #
      #   @see #default_btrfs_subvolume
      #
      #   @return [BtrfsSubvolume]
      storage_forward :default_btrfs_subvolume, as: "BtrfsSubvolume"

      # @!method btrfs_subvolumes
      #   Collection of Btrfs subvolumes of the filesystem
      #   @return [Array<BtrfsSubvolumes>]
      storage_forward :btrfs_subvolumes, as: "BtrfsSubvolume"

      # @!method find_btrfs_subvolume_by_path(path)
      #   Finds a subvolume by its path
      #
      #   @param path [String] subvolume path
      #   @return [BtrfsSubvolume, nil] nil if it does not find a subvolume with this path
      storage_forward :find_btrfs_subvolume_by_path, as: "BtrfsSubvolume"

      # Return the default subvolume, creating it when necessary
      #
      # If a specific default subvolume path is requested, create it; if not,
      # use the toplevel subvolume that is implicitly created by mkfs.btrfs.
      #
      # This default subvolume is the parent for all others on Btrfs 'filesystem'.
      #
      # @param path [String, nil] path for the default subvolume
      #
      # @return [BtrfsSubvolume]
      def get_or_create_default_btrfs_subvolume(path: nil)
        # The toplevel subvolume is implicitly created by mkfs.btrfs.
        # It does not have a name, and its subvolume ID is always 5.
        top_level = top_level_btrfs_subvolume
        if path && !path.empty?
          # If the "@" subvolume is specified in control.xml, this must be
          # created first, and it will be the parent of all the other
          # subvolumes. Otherwise, the toplevel subvolume is their direct parent.
          # Notice that this "@" subvolume does not show up in "btrfs subvolume
          # list".
          default_subvolume = top_level.create_btrfs_subvolume(path)
          default_subvolume.set_default_btrfs_subvolume
        else
          # Top level is set as default
          default_subvolume = top_level
        end

        default_subvolume
      end

      # Deletes a btrfs subvolume that belongs to the filesystem
      #
      # @param devicegraph [Devicegraph]
      # @param path [String] path of subvolume to delete
      def delete_btrfs_subvolume(devicegraph, path)
        subvolume = find_btrfs_subvolume_by_path(path)
        return if subvolume.nil?

        subvolume.remove_descendants
        devicegraph.to_storage_value.remove_device(subvolume.to_storage_value)
      end

      # The path that a new default btrfs subvolume should have
      #
      # @return [String]
      def self.default_btrfs_subvolume_path
        Yast::ProductFeatures.GetStringFeature("partitioning", "btrfs_default_subvolume")
      end

    protected

      def types_for_is
        super << :btrfs
      end
    end
  end
end
