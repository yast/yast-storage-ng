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

      # @!attribute configure_snapper
      #   Whether libstorage-ng should perform the initial steps to configure
      #   Snapper on this filesystem
      #
      #   @return [Boolean]
      storage_forward :configure_snapper
      storage_forward :configure_snapper=

      # Only Btrfs should support subvolumes
      def supports_btrfs_subvolumes?
        true
      end

      # Returns the default subvolume, creating it when necessary
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

        devicegraph.remove_btrfs_subvolume(subvolume)
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

      # Adds btrfs subvolumes defined from a list of specs
      #
      # @note A subvolume is added only when it does not exist in the filesystem
      #   and it makes sense for the current architecture.
      #
      # @see SubvolSpecification#create_btrfs_subvolume
      #
      # @param specs [Array<SubvolSpecification>]
      def add_btrfs_subvolumes(specs)
        arch_specs = Y2Storage::SubvolSpecification.for_current_arch(specs)

        arch_specs.each do |spec|
          path = btrfs_subvolume_path(spec.path)
          next unless find_btrfs_subvolume_by_path(path).nil?

          spec.create_btrfs_subvolume(self)
        end
      end

      # Returns a subvolume path for the filesystem
      #
      # The subvolume path is generated from the default subvolume path and
      # the relative version of path (without default subvolume prefix).
      #
      # @example
      #   filesystem.default_btrfs_subvolume.path # => "@"
      #
      #   filesystem.btrfs_subvolume_path("foo") # => "@/foo"
      #   filesystem.btrfs_subvolume_path("@/foo") # => "@/foo"
      #
      # @param subvolume_path [String] a subvolume path (absolute or relative)
      #
      # @return [String] subvolume path for the filesystem
      def btrfs_subvolume_path(subvolume_path)
        Btrfs.btrfs_subvolume_path(default_btrfs_subvolume.path, path_without_prefix(subvolume_path))
      end

      # Returns a subvolume mount point for the filesystem
      #
      # The subvolume mount point is generated from the filesystem mount point and
      # the subvolume path. When the filesystem is not mounted, the subvolume mount
      # point will be nil.
      #
      # @example
      #   filesystem.mount_point # => "/foo"
      #
      #   filesystem.btrfs_subvolume_mount_point("bar") # => "/foo/bar"
      #   filesystem.btrfs_subvolume_mount_point("@/bar") # => "/foo/bar"
      #
      # @param subvolume_path [String] a subvolume path (absolute or relative)
      #
      # @return [String, nil] nil whether the filesystem is not mounted
      def btrfs_subvolume_mount_point(subvolume_path)
        Btrfs.btrfs_subvolume_mount_point(mount_point, path_without_prefix(subvolume_path))
      end

      # Returns a subvolume path generated from a default subvolume path and
      # the a subvolume path
      #
      # @example
      #   Btrfs.btrfs_subvolume_path("@", "foo") # => "@/foo"
      #
      # @param default_subvolume_path [String] a default subvolume path
      # @param subvolume_path [String] a subvolume path
      #
      # @return [String, nil] nil whether any path is not valid
      def self.btrfs_subvolume_path(default_subvolume_path, subvolume_path)
        return nil if default_subvolume_path.nil? || subvolume_path.nil?
        File.join(default_subvolume_path, subvolume_path)
      end

      # Returns a subvolume mount point generated from a filesystem mount point and a
      # subvolume path
      #
      # @example
      #   Btrfs.btrfs_subvolume_mount_point("/foo", "bar") # => "/foo/bar"
      #
      # @param fs_mount_point [String] a filesystem mount point
      # @param subvolume_path [String] a subvolume path
      #
      # @return [String, nil] nil whether the filesystem mount point or the subvolume
      #   is not valid
      def self.btrfs_subvolume_mount_point(fs_mount_point, subvolume_path)
        return nil if fs_mount_point.nil? || fs_mount_point.empty?
        return nil if subvolume_path.nil?
        File.join(fs_mount_point, subvolume_path)
      end

      # The path that a new default btrfs subvolume should have
      #
      # TODO: The logic for obtaining a default subvolume path should be in the
      #   Y2Storage::SubvolSpecification class. In case that control file does not
      #   have a default path, it should fall back to a hard coded value.
      #
      # @return [String, nil] nil if default subvolume is not specified in control.xml
      def self.default_btrfs_subvolume_path
        section = "partitioning"
        feature = "btrfs_default_subvolume"

        return nil unless Yast::ProductFeatures.GetSection(section).key?(feature)

        Yast::ProductFeatures.GetStringFeature(section, feature)
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

      # Updates the list of subvolumes for the Btrfs filesystems
      #
      # Subvolumes are shadowed or unshadowed according to current mount points
      # in the whole system.
      #
      # @see #remove_shadowed_subvolumes
      # @see #restore_unshadowed_subvolumes
      #
      # @param devicegraph [Devicegraph]
      def self.refresh_subvolumes_shadowing(devicegraph)
        filesystems = BlkFilesystem.all(devicegraph).select(&:supports_btrfs_subvolumes?)
        return if filesystems.empty?

        filesystems.each do |filesystem|
          filesystem.remove_shadowed_subvolumes(devicegraph)
          filesystem.restore_unshadowed_subvolumes(devicegraph)
        end
      end

      # Removes current shadowed subvolumes
      # Only subvolumes that "can be auto deleted" will be removed.
      #
      # @param devicegraph [Devicegraph]
      def remove_shadowed_subvolumes(devicegraph)
        subvolumes = btrfs_subvolumes.select(&:can_be_auto_deleted?)
        subvolumes.each do |subvolume|
          next unless subvolume.shadowed?(devicegraph)
          shadow_btrfs_subvolume(devicegraph, subvolume.path)
        end
      end

      # Creates subvolumes that were previously removed because they were shadowed
      #
      # @param devicegraph [Devicegraph]
      def restore_unshadowed_subvolumes(devicegraph)
        auto_deleted_subvolumes.each do |spec|
          mount_point = btrfs_subvolume_mount_point(spec.path)
          next if BtrfsSubvolume.shadowed?(devicegraph, mount_point)
          unshadow_btrfs_subvolume(spec.path)
        end
      end

      # Determines the btrfs subvolumes prefix
      #
      # When a default subvolume name have been used, a subvolume named after
      # it lives under the #top_level_btrfs_subvolume. Otherwise, an empty
      # string will be taken as the default subvolume name.
      #
      # @return [String] Default subvolume name
      def subvolumes_prefix
        children = top_level_btrfs_subvolume.children
        children.size == 1 ? children.first.path : ""
      end

      # Determines whether the snapshots (snapper) are activated
      #
      # @return [Boolean] true if snapshots are present
      def snapshots?
        snapshots_root = File.join(subvolumes_prefix, ".snapshots")
        snapshots_subvolume = btrfs_subvolumes.any? { |s| s.path == snapshots_root }
        snapshots_subvolume || configure_snapper
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

      # Creates a previously auto deleted subvolume
      # The subvolume is removed from {auto_deleted_subvolumes} list
      #
      # @param path [String] subvolume path
      def unshadow_btrfs_subvolume(path)
        spec = auto_deleted_subvolumes.detect { |s| s.path == path }
        return false if spec.nil?

        subvolume = spec.create_btrfs_subvolume(self)
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

      def path_without_prefix(subvolume_path)
        subvolume_path.gsub(default_btrfs_subvolume.path, "")
      end

      def types_for_is
        super << :btrfs
      end
    end
  end
end
