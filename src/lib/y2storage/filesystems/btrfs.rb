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

      # Convert path to canonical form.
      #
      # That is, a single slash between elements. No leading or final slashes.
      #
      # @param path [String] subvolume path
      #
      # @return [String] sanitized subvolume path
      #
      def canonical_subvolume_name(path)
        path.squeeze("/").chomp("/").sub(/^\//, "")
      end

      # Check if a subvolume can be created.
      #
      # It can always be created if we're going to create the whole file
      # system anyway.
      #
      # If the file system exists already there must at least be nothing
      # else below path.
      #
      # @param path [String] subvolume path
      #
      # @return [Boolean]
      #
      def subvolume_can_be_created?(path)
        return true unless exists_in_raw_probed?
        !subvolume_descendants_exist?(path)
      end

      # List of subvolumes hierarchically below path
      #
      # That is, subvolumes starting with path.
      #
      # @param path [String] subvolume path
      #
      # @return [Array<BtrfsSubvolume>]
      #
      def subvolume_descendants(path)
        path = canonical_subvolume_name(path)
        path += "/" unless path.empty?
        btrfs_subvolumes.find_all { |sv| sv.path.start_with?(path) && sv.path != path }
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
      # @note The filesystem must have a default subvolume. When the default subvolume is deleted,
      #   the top level subvolume is set as the new default subvolume. Moreover, the top level
      #   subvolume cannot be deleted.
      #
      # @param devicegraph [Devicegraph]
      # @param path [String] path of subvolume to delete
      def delete_btrfs_subvolume(devicegraph, path)
        subvolume = find_btrfs_subvolume_by_path(path)
        return if subvolume.nil? || subvolume.top_level?

        deleted_default = subvolume.default_btrfs_subvolume?

        devicegraph.remove_btrfs_subvolume(subvolume)
        top_level_btrfs_subvolume.set_default_btrfs_subvolume if deleted_default
      end

      # Creates a new btrfs subvolume for the filesystem
      #
      # If the subvolume already exists, returns it.
      #
      # @note The subvolume mount point is generated from the filesystem mount point
      # and the subvolume path.
      #
      # @see #btrfs_subvolume_mount_point
      #
      # @param path [string] absolute subvolume path
      # @param nocow [Boolean] no copy on write property
      #
      # @return [BtrfsSubvolume, nil] new subvolume
      #
      def create_btrfs_subvolume(path, nocow)
        path = canonical_subvolume_name(path)

        subvolume = find_btrfs_subvolume_by_path(path)
        return subvolume if subvolume

        if !subvolume_can_be_created?(path)
          log.error "cannot create subvolume #{path}"
          return
        end

        if subvolume_descendants_exist?(path)
          create_btrfs_subvolume_full_rebuild(path, nocow)
        else
          create_btrfs_subvolume_nochecks(path, nocow)
        end
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
      # The subvolume path is generated from the subvolumes prefix and the relative version
      # of the subvolume path (without the subvolumes prefix).
      #
      # @example
      #   filesystem.subvolumes_prefix # => "@"
      #
      #   filesystem.btrfs_subvolume_path("foo") # => "@/foo"
      #   filesystem.btrfs_subvolume_path("@/foo") # => "@/foo"
      #
      # @param subvolume_path [String] a subvolume path (absolute or relative)
      #
      # @return [String] subvolume path for the filesystem
      def btrfs_subvolume_path(subvolume_path)
        Btrfs.btrfs_subvolume_path(subvolumes_prefix, path_without_prefix(subvolume_path))
      end

      # Returns a subvolume mount point for the filesystem
      #
      # The subvolume mount point is generated from the filesystem mount point and
      # the subvolume path. When the filesystem is not mounted, the subvolume mount
      # point will be nil.
      #
      # @example
      #   filesystem.mount_path # => "/foo"
      #
      #   filesystem.btrfs_subvolume_mount_point("bar") # => "/foo/bar"
      #   filesystem.btrfs_subvolume_mount_point("@/bar") # => "/foo/bar"
      #
      # @param subvolume_path [String] a subvolume path (absolute or relative)
      #
      # @return [String, nil] nil whether the filesystem is not mounted
      def btrfs_subvolume_mount_point(subvolume_path)
        Btrfs.btrfs_subvolume_mount_point(mount_path, path_without_prefix(subvolume_path))
      end

      # Returns a subvolume path generated from a default subvolume path and
      # the a subvolume path
      #
      # The path is forced to be relative.
      #
      # @example
      #   Btrfs.btrfs_subvolume_path("@", "foo") # => "@/foo"
      #
      # @param subvolumes_prefix [String] prefix for the subvolumes
      # @param subvolume_path [String] a subvolume path
      #
      # @return [String, nil] nil whether any path is not valid
      def self.btrfs_subvolume_path(subvolumes_prefix, subvolume_path)
        return nil if subvolumes_prefix.nil? || subvolume_path.nil?
        path = Pathname(File.join(subvolumes_prefix, subvolume_path))
        return path.to_s unless path.absolute?
        path.relative_path_from(MountPoint::ROOT_PATH).to_s
      end

      # Returns a subvolume mount point generated from a filesystem mount point and a
      # subvolume path
      #
      # @example
      #   Btrfs.btrfs_subvolume_mount_point("/foo", "bar") # => "/foo/bar"
      #
      # @param fs_mount_path [String] a filesystem mount path
      # @param subvolume_path [String] a subvolume path
      #
      # @return [String, nil] nil whether the filesystem mount path or the subvolume
      #   path is not valid
      def self.btrfs_subvolume_mount_point(fs_mount_path, subvolume_path)
        return nil if fs_mount_path.nil?
        return nil if subvolume_path.nil?
        File.join(fs_mount_path, subvolume_path)
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
          mount_path = btrfs_subvolume_mount_point(spec.path)
          next if BtrfsSubvolume.shadowed?(devicegraph, mount_path)
          unshadow_btrfs_subvolume(spec.path)
        end
      end

      # Determines the btrfs subvolumes prefix
      #
      # When a default subvolume name have been used, a subvolume named after
      # it lives under the #top_level_btrfs_subvolume. Otherwise, an empty
      # string will be taken as the default subvolume name.
      #
      # If the filesystem does not exists yet, consider the default Btrfs subvolume
      # (#default_btrfs_subvolume) path as the prefix.
      #
      # @return [String] Default subvolume name
      def subvolumes_prefix
        return default_btrfs_subvolume.path unless exists_in_raw_probed?
        children = top_level_btrfs_subvolume.children.reject { |s| snapper_path?(s.path) }
        children.size == 1 ? children.first.path : ""
      end

      # Determines whether the snapshots (snapper) are activated
      #
      # @return [Boolean] true if snapshots are present
      def snapshots?
        snapshots_subvolume = btrfs_subvolumes.any? { |s| s.path == snapshots_root }
        snapshots_subvolume || configure_snapper
      end

      # @return [String] Snapshots root subvolume name
      SNAPSHOTS_ROOT_SUBVOL_NAME = ".snapshots".freeze

      # Determines the snapshots root subvolume
      #
      # @return [String] Snapshots root subvolume
      def snapshots_root
        @snapshots_root ||= Pathname.new(subvolumes_prefix).join(SNAPSHOTS_ROOT_SUBVOL_NAME).to_s
      end

      # Copy the mount_by mode from this btrfs to all subvolumes (that have a
      # mount point).
      #
      # @return [Filesystems::MountByType, nil]
      #
      def copy_mount_by_to_subvolumes
        return nil if mount_point.nil?

        mount_by = mount_point.mount_by
        log.info "copying mount_by #{mount_by} to all subvolumes"
        btrfs_subvolumes.each do |subvol|
          next if subvol.mount_point.nil?
          subvol.mount_point.mount_by = mount_by
        end
        mount_by
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
        subvolume_path.gsub(subvolumes_prefix, "")
      end

      def types_for_is
        super << :btrfs
      end

    private

      # Check for existing descendants of a subvolume path.
      #
      # @param path [String] subvolume path
      #
      # @return [Boolean]
      #
      def subvolume_descendants_exist?(path)
        !subvolume_descendants(path).empty?
      end

      # Find the most suitable parent for a new subvolume
      #
      # That is, the one with the longest path that is part of path.
      #
      # @param path [String] subvolume path
      #
      # @return [BtrfsSubvolume] parent subvolume
      #
      def suitable_parent_subvolume(path)
        while path.include?("/")
          path = path.gsub(/\/[^\/]*$/, "")
          subvolume = find_btrfs_subvolume_by_path(path)
          return subvolume if subvolume
        end

        top_level_btrfs_subvolume
      end

      # Create a new btrfs subvolume for the filesystem
      #
      # This method must be used if the new subvolume does not fit into the
      # existing subvolume hierarchy.
      #
      # It will remove all subvolumes but the top level one and then rebuild
      # them from scratch including the new subvolume.
      #
      # @see #create_btrfs_subvolume
      #
      # @param path [string] absolute subvolume path
      # @param nocow [Boolean] no copy on write property
      #
      # @return [BtrfsSubvolume] new subvolume
      #
      def create_btrfs_subvolume_full_rebuild(path, nocow)
        log.info "subvolume hierarchy mismatch - recreate all"

        subvolumes = btrfs_subvolumes.map { |x| x.top_level? ? nil : [x.path, x.nocow?] }.compact
        subvolumes.push([path, nocow])

        default_subvolume = default_btrfs_subvolume.path
        top_level_btrfs_subvolume.set_default_btrfs_subvolume

        log.info "recreating subvolumes #{subvolumes}, default #{default_subvolume}"

        top_level_btrfs_subvolume.remove_descendants

        # sort: shortest path first
        subvolumes.sort! { |x, y| x[0] <=> y[0] }
        subvolumes.each { |x| create_btrfs_subvolume_nochecks(*x) }

        subvolume = find_btrfs_subvolume_by_path(default_subvolume)
        subvolume.set_default_btrfs_subvolume if subvolume

        find_btrfs_subvolume_by_path(path)
      end

      # Create a new btrfs subvolume for the filesystem
      #
      # @see #create_btrfs_subvolume
      #
      # This method does not verify if the subvolume can be added to the
      # existing subvolume hierarchy. Use {create_btrfs_subvolume} instead.
      #
      # @param path [string] absolute subvolume path
      # @param nocow [Boolean] no copy on write property
      #
      # @return [BtrfsSubvolume] new subvolume
      #
      def create_btrfs_subvolume_nochecks(path, nocow)
        parent_subvolume = suitable_parent_subvolume(path)

        log.info "creating subvolume #{path} at #{parent_subvolume.path}"

        subvolume = parent_subvolume.create_btrfs_subvolume(path)
        subvolume.nocow = nocow
        subvolume_mount_path = btrfs_subvolume_mount_point(path)
        subvolume.create_mount_point(subvolume_mount_path) unless subvolume_mount_path.nil?
        subvolume
      end

      # Determines whether a subvolume path is reserved for snapper
      #
      # There is some kind of egg and chicken problem: we should know the
      # #subvolumes_prefix in order to get the right path but we need to filter
      # snapshots in order to get the #subvolumes prefix. So we are assuming
      # that finding SNAPSHOTS_ROOT_SUBVOL_NAME in the first or the second
      # component of the path should be enough.
      #
      # @return [Boolean]
      def snapper_path?(path)
        path.split("/")[0..1].include?(SNAPSHOTS_ROOT_SUBVOL_NAME)
      end
    end
  end
end
