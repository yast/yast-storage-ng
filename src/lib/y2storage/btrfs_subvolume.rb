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

    # Whether the subvolume can be shadowed
    # @return [Boolean]
    def can_be_shadowed?
      value = userdata_value(:can_be_shadowed)
      value.nil? ? false : value
    end

    # @see #can_be_shadowed?
    def can_be_shadowed=(value)
      save_userdata(:can_be_shadowed, value)
    end

    # Checks whether the subvolume is shadowed by any other mount point in the system
    #
    # @param devicegraph [Devicegraph]
    #
    # @return [Boolean] true if the subvolume is shadowed
    def shadowed?(devicegraph)
      !shadowers(devicegraph).empty?
    end

    # Returns the devices that shadow the subvolume
    #
    # It prevents to return the subvolume itself or its filesystem as shadower.
    #
    # @param devicegraph [Devicegraph]
    #
    # @return [Array<Mountable>] shadowers
    def shadowers(devicegraph)
      shadowers = BtrfsSubvolume.shadowers(devicegraph, mount_point)
      shadowers.reject { |s| s.sid == sid || s.sid == btrfs.sid }
    end

    # Checks whether a mount point is shadowing to another mount point
    #
    # @note The existence of devices with that mount points is not checked.
    #
    # @param mount_point [String]
    # @param other_mount_point [String]
    #
    # @return [Boolean] true if {other_mount_point} is shadowed by {mount_point}
    def self.shadowing?(mount_point, other_mount_point)
      return false if mount_point.nil? || other_mount_point.nil?
      return false if mount_point.empty? || other_mount_point.empty?
      # Just checking with start_with? is not sufficient:
      # "/bootinger/schlonz".start_with?("/boot") -> true
      # So append "/" to make sure only complete subpaths are compared:
      # "/bootinger/schlonz/".start_with?("/boot/") -> false
      # "/boot/schlonz/".start_with?("/boot/") -> true
      check_path = "#{other_mount_point}/"
      check_path.start_with?("#{mount_point}/")
    end

    # Checks whether a mount point is currently shadowed by any other mount point
    #
    # @param devicegraph [Devicegraph]
    # @param mount_point [String] mount point to check
    #
    # @return [Boolean]
    def self.shadowed?(devicegraph, mount_point)
      !shadowers(devicegraph, mount_point).empty?
    end

    # Returns the current shadowers for a specific mount point
    #
    # @param devicegraph [Devicegraph]
    # @param mount_point [String] mount point
    #
    # @return [Array<Mountable>] shadowers
    def self.shadowers(devicegraph, mount_point)
      Mountable.all(devicegraph).select { |m| shadowing?(m.mount_point, mount_point) }
    end

  protected

    def types_for_is
      super << :btrfs_subvolume
    end
  end
end
