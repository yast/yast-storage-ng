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
require "y2storage/mount_point"

module Y2Storage
  # Abstract class to represent something that can be mounted, like a filesystem
  # or a Btrfs subvolume
  #
  # This is a wrapper for Storage::Mountable
  class Mountable < Device
    wrap_class Storage::Mountable, downcast_to: ["Filesystems::Base", "BtrfsSubvolume"]

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Mountable>] all mountable devices in the devicegraph
    storage_class_forward :all, as: "Mountable"

    storage_forward :storage_create_mount_point, to: :create_mount_point, as: "MountPoint"
    private :storage_create_mount_point

    storage_forward :storage_remove_mount_point, to: :remove_mount_point
    private :storage_create_mount_point

    # @!method mount_point
    #   @return [MountPoint]
    storage_forward :mount_point, as: "MountPoint", check_with: :has_mount_point

    # Directory in which the device should be mounted
    #
    # @see MountPoint#path
    #
    # @return [String, nil] nil if it has no mount point
    def mount_path
      return nil if mount_point.nil?

      mount_point.path
    end

    # Sets the mount point path
    #
    # @note A new mount point is created if it does not exist, see {#create_mount_point}
    #
    # @param path [String]
    def mount_path=(path)
      mp = mount_point || create_mount_point("")
      mp.path = path
    end

    # Mount by method
    #
    # @see MountPoint#mount_by
    #
    # @return [Filesystems::MountByType, nil] nil if it has no mount point
    def mount_by
      return nil if mount_point.nil?

      mount_point.mount_by
    end

    # Mount options
    #
    # @see MountPoint#mount_options
    #
    # @return [Array<String>] empty if it has no mount point
    def mount_options
      return [] if mount_point.nil?

      mount_point.mount_options
    end

    # Is the mount persistent?
    #
    # @return [Boolean] true if the mount point is saved to /etc/fstab
    #   (and will be mounted at boot again), false otherwise
    def persistent?
      return false if mount_point.nil?

      mount_point.in_etc_fstab?
    end

    # Checks whether the device is mounted as root
    #
    # @return [Boolean]
    def root?
      return false if mount_point.nil?
      mount_point.root?
    end

    # Creates a mount point object for the device
    #
    # @param path [String]
    # @return [MountPoint]
    def create_mount_point(path)
      mp = storage_create_mount_point(path)
      update_etc_status
      mp
    end

    # Removes the mount point object associated to the device
    #
    # @raise [Storage::Exception] if the mountable has no mount point
    def remove_mount_point
      storage_remove_mount_point
      update_etc_status
    end
  end
end
