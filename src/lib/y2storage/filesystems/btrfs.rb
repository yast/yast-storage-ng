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

      # Only Btrfs should support subvolumes
      def supports_btrfs_subvolumes?
        true
      end

      # Return the default subvolume, creating it when necessary
      #
      # If a specific default subvolume path is requested, returns a subvolume with
      # that path. If requested path is nil, returns the current default subvolume,
      # presumably the toplevel one implicitly created by mkfs.btrfs.
      #
      # This default subvolume is the parent for all others on Btrfs 'filesystem'.
      #
      # @note When requested path is the empty string and a default subvolume already
      #   exists (for example @), top level subvolume will be set as default.
      #
      # @param path [String, nil] path for the default subvolume
      #
      # @return [BtrfsSubvolume]
      def ensure_default_btrfs_subvolume(path: nil)
        return default_btrfs_subvolume if path.nil?

        # If a given default subvolume (typically "@") is specified in control.xml, this must be
        # created first (or promoted to default if it already exists), and it will be the parent of
        # all the other subvolumes. Otherwise, the toplevel subvolume would be their direct parent.
        # Notice that this "@" subvolume does not show up in "btrfs subvolume list".
        subvolume = find_btrfs_subvolume_by_path(path)
        subvolume ||= top_level_btrfs_subvolume.create_btrfs_subvolume(path)
        subvolume.set_default_btrfs_subvolume unless subvolume.default_btrfs_subvolume?

        subvolume
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

      # Creates a btrfs subvolume associated to the filesystem
      #
      # @note The subvolume mount point is generated from the {path} and the
      #   filesystem mount point.
      #
      # @see #btrfs_subvolume_mount_point
      #
      # @param path [string] absolute subvolume path
      # @param nocow [Boolean] no copy on write property 
      def create_btrfs_subvolume(path, nocow)
        subvolume = default_btrfs_subvolume.create_btrfs_subvolume(path)
        subvolume.nocow = nocow
        subvolume.mountpoint = btrfs_subvolume_mount_point(path)
        subvolume
      end

      # Returns a subvolume mount point build from the path
      #
      # The subvolume mount point is generated from the filesystem mount point and
      # the relative version of {path}.
      #
      # @param path [String] a subvolume path
      #
      # @return [String, nil] nil whether the filesystem is not mounted
      def btrfs_subvolume_mount_point(path)
        return nil if mount_point.nil?
        File.join(mount_point, btrfs_subvolume_relative_path(path))
      end

      # Returns a proper absolute subvolume path for the filesystem
      #
      # The subvolume absolute path is generated from the default subvolume path and
      # the relative version of {path}.
      #
      # @param path [String] a subvolume path (absolute or relative)
      #
      # @return [String] subvolume absolute path for the filesystem
      def btrfs_subvolume_path(path)
        File.join(default_btrfs_subvolume_prefix, btrfs_subvolume_relative_path(path))
      end

      # The path that a new default btrfs subvolume should have
      #
      # @return [String, nil] nil if default subvolume is not specified in control.xml
      def self.default_btrfs_subvolume_path
        section = "partitioning"
        feature = "btrfs_default_subvolume"

        return nil unless Yast::ProductFeatures.GetSection(section).key?(feature)

        Yast::ProductFeatures.GetStringFeature(section, feature)
      end

    protected

      def btrfs_subvolume_relative_path(path)
        path.sub(default_btrfs_subvolume_prefix, "")
      end

      def default_btrfs_subvolume_prefix
        default_btrfs_subvolume.path + "/"
      end

      def types_for_is
        super << :btrfs
      end
    end
  end
end
