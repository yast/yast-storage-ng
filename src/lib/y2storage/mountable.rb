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
require "y2storage/device"

module Y2Storage
  # Abstract class to represent something that can be mounted, like a filesystem
  # or a Btrfs subvolume
  #
  # This is a wrapper for Storage::Mountable
  class Mountable < Device
    wrap_class Storage::Mountable, downcast_to: ["Filesystems::Base", "BtrfsSubvolume"]

    # @!method type
    #   @return [Filesystems::Type]
    storage_forward :type, as: "Filesystems::Type"

    # @!attribute mount_by
    #   @return [Filesystems::MountByType]
    storage_forward :mount_by, as: "Filesystems::MountByType"
    storage_forward :mount_by=

    # @!method fstab_options
    #   Options to use in /etc/fstab for a newly created filesystem.
    #
    #   @note This returns an array based on the underlying SWIG vector,
    #   modifying the returned object will have no effect in the Mountable
    #   object. Use #fstab_options= to actually change the value. See examples.
    #
    #   @example This will not modify the options
    #     mountable.fstab_options << "ro"
    #     mountable.fstab_options # "ro" was not added
    #
    #   @example This will work as expected
    #     mountable.fstab_options = mountable.fstab_options + ["ro"]
    #     mountable.fstab_options # "ro" was added
    #
    #   @see fstab_options=
    #
    #   @return [Array<String>]
    storage_forward :fstab_options

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Mountable>] all mountable devices in the devicegraph
    storage_class_forward :all, as: "Mountable"

    # Directory in which the device should be mounted
    #
    # @note This will be shortly implemented directly in libstorage-ng
    #
    # @return [String]
    def mountpoint
      to_storage_value.mountpoints.to_a.first
    end

    alias_method :mount_point, :mountpoint

    # Sets the directory in which the device should be mounted
    #
    # @note This will be shortly implemented directly in libstorage-ng
    #
    # @param path [String]
    # @return [String]
    def mountpoint=(path)
      to_storage_value.add_mountpoint(path.to_s)
      mountpoint
    end

    alias_method :mount_point=, :mountpoint=

    # Sets the options to use in /etc/fstab for a newly created filesystem.
    #
    # @param new_options [Array<String>]
    # @return [Array<String>]
    def fstab_options=(new_options)
      # A direct assignation of a regular Ruby collection (like Array) will not
      # work because Storage::Mountable#fstab_options= expects an argument with
      # a very specific SWIG type (std::list)
      to_storage_value.fstab_options.clear
      new_options.each { |opt| to_storage_value.fstab_options << opt } if new_options
      fstab_options
    end

    # Checks whether the filesystem is mounted as root
    # @return [Boolean]
    def root?
      mount_point == ROOT_PATH
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
      # Just checking with start_with? is not sufficient:
      # "/bootinger/schlonz".start_with?("/boot") -> true
      # So append "/" to make sure only complete subpaths are compared:
      # "/bootinger/schlonz/".start_with?("/boot/") -> false
      # "/boot/schlonz/".start_with?("/boot/") -> true
      check_path = "#{other_mount_point}/"
      check_path.start_with?("#{mount_point}/")
    end

    # Checks whether a mount point is currently shadowed by other specific mount point
    #
    # @param devicegraph [Devicegraph]
    # @param mount_point [String] mount point to check
    # @param other_mount_point [String] mount point
    #
    # @return [Boolean] true if {mount_point} is shadowed by {other_mount_point}
    def self.shadowed_by?(devicegraph, mount_point, other_mount_point)
      device = Mountable.all(devicegraph).detect? { |m| m.mount_point == other_mount_point }
      return false if device.nil?

      Mountable.shadowing?(device.mount_point, mount_point)
    end

    # Checks whether a mount point is currently shadowed by any other mount point
    #
    # @param devicegraph [Devicegraph]
    # @param mount_point [String] mount point to check
    #
    # @return [Boolean]
    def self.shadowed?(devicegraph, mount_point)
      Mountable.all(devicegraph).any? { |m| Mountable.shadowing?(m.mount_point, mount_point) }
    end

    # Returns the current shadowers for a specific mount point
    #
    # @param devicegraph [Devicegraph]
    # @param mount_point [String] mount point
    #
    # @return [Array<Mountable>] shadowers
    def self.shadowers(devicegraph, mount_point)
      Mountable.all(devicegraph).select { |m| Mountable.shadowing?(m.mount_point, mount_point) }
    end

    # Checks whether the current mount point is shadowed by other specific mount point
    #
    # @param devicegraph [Devicegraph]
    # @param mount_point [String] other mount point
    #
    # @return [Boolean] true if the current mount point is shadowed by {mount_point}
    def shadowed_by?(devicegraph, mount_point)
      shadowers(devicegraph).map(&:mount_point).include?(mount_point)
    end

    # Checks whether the current mount point is shadowed by any other mount point
    #
    # @param devicegraph [Devicegraph]
    #
    # @return [Boolean]
    def shadowed?(devicegraph)
      !shadowers(devicegraph).empty?
    end

    # Returns the list of shadowers for the current mount point. It prevents to return
    # itself as shadower.
    #
    # @param devicegraph [Devicegraph]
    #
    # @return [Array<Mountable>] shadowers
    def shadowers(devicegraph)
      shadowers = Mountable.shadowers(devicegraph, mount_point)
      shadowers.reject { |m| m.sid == sid }
    end

  private

    ROOT_PATH = "/".freeze
    
  end
end
