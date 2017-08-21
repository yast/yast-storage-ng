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
require "y2storage/subvol_specification"

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

      # Creates a new btrfs subvolume for the filesystem
      #
      # @note The subvolume mount point is generated from the filesystem mount point
      # and the subvolume path.
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

      # Returns a subvolume mount point build from a path
      #
      # The subvolume mount point is generated from the filesystem mount point and
      # the relative version of {path}. When the filesystem is not mounted, the
      # subvolume mount point it will be nil.
      #
      # @param path [String] a subvolume path (absolute or relative)
      #
      # @return [String, nil] nil whether the filesystem is not mounted
      def btrfs_subvolume_mount_point(path)
        return nil if mount_point.nil? || mount_point.empty?
        File.join(mount_point, btrfs_subvolume_relative_path(path))
      end

      # Subvolumes that have been automatically deleted without user
      # intervention to avoid shadowing.
      #
      # @note This relies on the userdata mechanism (see {#userdata_value}), so
      # modifications to the returned object will not be automatically persisted
      # to the device. Always use {#auto_deleted_subvolumes=} to modify the list.
      #
      # @return [Array<SubvolSpecification>]
      def auto_deleted_subvolumes
        userdata_value(:auto_deleted_subvolumes) || []
      end

      # Stores the information for {#auto_deleted_subvolumes}
      #
      # @param subvolumes [Array<SubvolSpecification>]
      def auto_deleted_subvolumes=(subvolumes)
        save_userdata(:auto_deleted_subvolumes, subvolumes || [])
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

      # Updates the list of subvolumes for the Btrfs filesystem mounted at root
      #
      # Subvolumes are shadowed or unshadowed according to current mount points
      # in the whole system.
      #
      # @see #shadow_btrfs_subvolumes
      # @see #unshadow_btrfs_subvolumes
      #
      # @param devicegraph [Devicegraph]
      def self.refresh_root_subvolumes_shadowing(devicegraph)
        filesystem = BlkFilesystem.all(devicegraph).detect { |f| f.root? && f.is?(:btrfs) }
        return if filesystem.nil?

        filesystem.shadow_btrfs_subvolumes(devicegraph)
        filesystem.unshadow_btrfs_subvolumes(devicegraph)
      end

      # Removes current shadowed subvolumes
      # Only subvolumes that "can be shadowed" will be removed.
      #
      # @param devicegraph [Devicegraph]
      def shadow_btrfs_subvolumes(devicegraph)
        subvolumes = btrfs_subvolumes.select(&:can_be_shadowed?)
        subvolumes.each do |subvolume|
          next unless subvolume.shadowed?(devicegraph)
          shadow_btrfs_subvolume(devicegraph, subvolume.path)
        end
      end

      # Creates subvolumes that were previously removed because they were shadowed
      #
      # @param devicegraph [Devicegraph]
      def unshadow_btrfs_subvolumes(devicegraph)
        auto_deleted_subvolumes.each do |spec|
          mount_point = btrfs_subvolume_mount_point(spec.path)
          next if BtrfsSubvolume.shadowed?(devicegraph, mount_point)
          unshadow_btrfs_subvolume(devicegraph, spec.path)
        end
      end

    protected

      # Removes a subvolume
      # The subvolume is cached into {auto_deleted_subvolumes} list
      #
      # @param devicegraph [Devicegraph]
      # @param path [String] subvolume path
      def shadow_btrfs_subvolume(devicegraph, path)
        subvolume = find_btrfs_subvolume_by_path(path)
        return false if subvolume.nil?

        add_auto_deleted_subvolume(subvolume.path, subvolume.nocow?)
        delete_btrfs_subvolume(devicegraph, subvolume.path)
        true
      end

      # Creates a previously shadowed subvolume
      # The subvolume is removed from {auto_deleted_subvolumes} list
      #
      # @param devicegraph [Devicegraph]
      # @param path [String] subvolume path
      def unshadow_btrfs_subvolume(_devicegraph, path)
        spec = auto_deleted_subvolumes.detect { |s| s.path == path }
        return false if spec.nil?

        subvolume = create_btrfs_subvolume(spec.path, !spec.copy_on_write)
        subvolume.can_be_shadowed = true
        remove_auto_deleted_subvolume(subvolume.path)
        true
      end

      # Adds a subvolume to the list of auto deleted subvolumes
      # @see #auto_deleted_list
      #
      # @param path [String] subvolume path
      # @param nocow [Boolean] nocow attribute
      def add_auto_deleted_subvolume(path, nocow)
        spec = Y2Storage::SubvolSpecification.new(path, copy_on_write: !nocow)
        specs = auto_deleted_subvolumes.push(spec)
        self.auto_deleted_subvolumes = specs
      end

      # Removes a subvolume from the list of auto deleted subvolumes
      # @see #auto_deleted_list
      #
      # @param path [String] subvolume path
      def remove_auto_deleted_subvolume(path)
        specs = auto_deleted_subvolumes.reject { |s| s.path == path }
        self.auto_deleted_subvolumes = specs
      end

      # Relative version of a subvolume path
      # @return [String]
      def btrfs_subvolume_relative_path(path)
        path.sub(default_btrfs_subvolume_prefix, "")
      end

      # Path prefix for subvolumes path
      # @return [String]
      def default_btrfs_subvolume_prefix
        default_btrfs_subvolume.path + "/"
      end

      def types_for_is
        super << :btrfs
      end
    end
  end
end
