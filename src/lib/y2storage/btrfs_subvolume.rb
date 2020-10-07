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
require "y2storage/mountable"

module Y2Storage
  # A subvolume in a Btrfs filesystem
  #
  # This is a wrapper for Storage::BtrfsSubvolume
  class BtrfsSubvolume < Mountable
    wrap_class Storage::BtrfsSubvolume

    # @!method btrfs
    #   @return [Filesystems::BlkFilesystem]
    storage_forward :btrfs, as: "Filesystems::BlkFilesystem"
    alias_method :blk_filesystem, :btrfs
    alias_method :filesystem, :btrfs

    # @!method id
    #   @return [Integer]
    storage_forward :id

    # @!method top_level?
    #   @return [Boolean] whether this is the top-level subvolume
    storage_forward :top_level?

    # @!method top_level_btrfs_subvolume
    #   @return [BtrfsSubvolume] top-level subvolume
    storage_forward :top_level_btrfs_subvolume, as: "BtrfsSubvolume"

    # @!method path
    #   @return [String] path of the subvolume
    storage_forward :path

    # @!method nocow?
    #   @return [Boolean] whether No-Copy-On-Write is enabled
    storage_forward :nocow?

    # @!method nocow=(value)
    #   @see #nocow?
    #   @param value [Boolean]
    storage_forward :nocow=

    # @!method default_btrfs_subvolume?
    #   @return [Boolean] whether this is the default subvolume
    storage_forward :default_btrfs_subvolume?

    # @!method create_btrfs_subvolume(path)
    #   @param path [String] path of the new subvolume
    #   @return [BtrfsSubvolume]
    storage_forward :create_btrfs_subvolume, as: "BtrfsSubvolume"

    # Sets this subvolume as the default one
    def set_default_btrfs_subvolume
      # The original libstorage method is wrongly renamed to
      # :default_btrfs_subvolume= by SWIG, because it's named like a setter
      # although it is not.
      to_storage_value.public_send(:default_btrfs_subvolume=)
    end

    # Create a mount point with the same mount_by as the parent Btrfs.
    #
    # @param path [String]
    # @return [MountPoint]
    def create_mount_point(path)
      super
      copy_mount_by_from_filesystem
      mount_point
    end

    # Copy the parent filesystem's mount_by from the parent filesystem.
    #
    # @return [Filesystems::MountByType, nil]
    def copy_mount_by_from_filesystem
      return nil if mount_point.nil? || filesystem.mount_point.nil?

      mount_point.manual_mount_by = filesystem.mount_point.manual_mount_by?
      mount_point.assign_mount_by(filesystem.mount_point.mount_by)
    end

    # Whether the subvolume can be auto deleted, for example when a proposed
    # subvolume is shadowed
    #
    # @return [Boolean]
    def can_be_auto_deleted?
      value = userdata_value(:can_be_auto_deleted)
      value.nil? ? false : value
    end

    # @see #can_be_auto_deleted?
    def can_be_auto_deleted=(value)
      save_userdata(:can_be_auto_deleted, value)
    end

    # Checks whether the subvolume is shadowed by any other mount point in the system
    #
    # @return [Boolean] true if the subvolume is shadowed
    def shadowed?
      !shadowers.empty?
    end

    # Returns the devices that shadow the subvolume
    #
    # It prevents to return the subvolume itself or its filesystem as shadower.
    #
    # @return [Array<Mountable>] shadowers
    def shadowers
      shadowers = BtrfsSubvolume.shadowers(devicegraph, mount_path)
      shadowers.reject { |s| s.sid == sid || s.sid == btrfs.sid }
    end

    # Checks whether a mount path is shadowing another mount path
    #
    # @note The existence of devices with that mount paths is not checked.
    #
    # @param mount_path [String]
    # @param other_mount_path [String]
    #
    # @return [Boolean] true if other_mount_path is shadowed by mount_path
    def self.shadowing?(mount_path, other_mount_path)
      return false if mount_path.nil? || other_mount_path.nil?
      return false if mount_path.empty? || other_mount_path.empty?

      # Just checking with start_with? is not sufficient:
      # "/bootinger/schlonz".start_with?("/boot") -> true
      # So append "/" to make sure only complete subpaths are compared:
      # "/bootinger/schlonz/".start_with?("/boot/") -> false
      # "/boot/schlonz/".start_with?("/boot/") -> true
      check_path = "#{other_mount_path}/"
      check_path.start_with?("#{mount_path}/")
    end

    # Checks whether a mount path is currently shadowed by any other mount path
    #
    # @param devicegraph [Devicegraph]
    # @param mount_path [String] mount point to check
    #
    # @return [Boolean]
    def self.shadowed?(devicegraph, mount_path)
      !shadowers(devicegraph, mount_path).empty?
    end

    # Returns the current shadowers for a specific mount point
    #
    # @param devicegraph [Devicegraph]
    # @param mount_path [String]
    #
    # @return [Array<Mountable>] shadowers
    def self.shadowers(devicegraph, mount_path)
      Mountable.all(devicegraph).select { |m| shadowing?(m.mount_path, mount_path) }
    end

    # Returns the assigned qgroup
    #
    # @return [BtrfsQgroup,nil] Assigned qgroup; nil if no qgroup is assigned
    def qgroup
      filesystem.qgroup_for(id)
    end

    # Assigns the referenced extents quota
    #
    # @param value [DiskSize] Limit for referenced extents; DiskSize.unlimited to remove the limit
    def rfer_limit=(value)
      save_userdata(:rfer_limit, value)
    end

    # Assigns the exclusive extents quota
    #
    # @param value [DiskSize] Limit for exclusive extents; DiskSize.unlimited to remove the limit
    def excl_limit=(value)
      save_userdata(:excl_limit, value)
    end

    # Returns the referenced extents quota
    #
    # @param value [DiskSize] Limit for referenced extents; DiskSize.unlimited if no limit
    # @return [DiskSize]
    def rfer_limit
      user_limit = userdata_value(:rfer_limit)
      return user_limit if user_limit
      return qgroup.rfer_limit if qgroup
      DiskSize.unlimited
    end

    # Returns the exclusive extents quota
    #
    # @param value [DiskSize] Limit for exclusive extents; DiskSize.unlimited if no limit
    def excl_limit
      user_limit = userdata_value(:excl_limit)
      return user_limit if user_limit
      return qgroup.excl_limit if qgroup
      DiskSize.unlimited
    end

    protected

    def types_for_is
      super << :btrfs_subvolume
    end
  end
end
