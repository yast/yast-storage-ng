# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "pathname"

module Y2Storage
  # Class to represent a mount point
  #
  # This is a wrapper for Storage::MountPoint
  class MountPoint < Device
    wrap_class Storage::MountPoint

    # @return [Pathname] Object that represents the root path
    ROOT_PATH = Pathname.new("/").freeze

    # @return [Pathname] Object that represents the swap path
    SWAP_PATH = Pathname.new("swap").freeze

    # @!method self.create(devicegraph, path)
    #   @param devicegraph [Devicegraph]
    #   @param path [String]
    #
    #   @return [MountPoint]
    storage_class_forward :create, as: "MountPoint"

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #
    #   @return [Array<MountPoint>] all mount points in the devicegraph
    storage_class_forward :all, as: "MountPoint"

    # @!method self.find_by_path(devicegraph, path)
    #   @param devicegraph [Devicegraph]
    #   @param path [String] path of the mount point. See {#path}
    #
    #   @return [Array<MountPoint>]
    storage_class_forward :find_by_path, as: "MountPoint"

    # @!method path
    #   @return [String]
    storage_forward :path

    # @!method path=(path)
    #   @param path [String]
    #   @raise [Storage::InvalidMountPointPath] if trying to set an invalid path
    storage_forward :path=

    # @!attribute mount_by
    #   @return [Filesystems::MountByType]
    storage_forward :mount_by, as: "Filesystems::MountByType"
    storage_forward :mount_by=

    # @!method mount_options
    #   Options to use in /etc/fstab for a newly created mount point.
    #
    #   @note This returns an array based on the underlying SWIG vector,
    #   modifying the returned object will have no effect in the MountPoint
    #   object. Use #mount_options= to actually change the value. See examples.
    #
    #   @example This will not modify the options
    #     mount_point.mount_options << "ro"
    #     mount_point.mount_options # "ro" was not added
    #
    #   @example This will work as expected
    #     mount_point.mount_options = mount_point.mount_options + ["ro"]
    #     mount_point.mount_options # "ro" was added
    #
    #   @return [Array<String>]
    storage_forward :mount_options

    # Sets mount options
    #
    # @note Avoid overriding the subvolume option for btrfs subvolumes unless
    #   you are certain what you are doing.
    #
    # @param options [Array<String>]
    def mount_options=(options)
      to_storage_value.mount_options.clear
      options.each { |o| to_storage_value.mount_options << o } if options
      mount_options
    end

    # @!method set_default_mount_by
    #   Set the mount-by method to the global default, see Storage::get_default_mount_by()
    storage_forward :set_default_mount_by, to: :default_mount_by=

    # @!method possible_mount_bys
    #   Returns the possible mount-by methods for the mount point.
    #   LABEL is included even if the filesystem label is not set.
    #
    #   @return [Array<Filesystems::MountByType>]
    storage_forward :possible_mount_bys, as: "Filesystems::MountByType"

    # @!method set_default_mount_options
    #   Sets the mount options to the default mount options. So far the
    #   default mount options only contain the subvol for btrfs subvolumes.
    storage_forward :set_default_mount_options, to: :default_mount_options=

    # @!method in_etc_fstab?
    #   Whether the mount point is present (probed devicegraph) or
    #   will be present (staging devicegraph) in /etc/fstab
    #
    #   @return [Boolean]
    storage_forward :in_etc_fstab?

    # @!method mountable
    #   Gets the mountable of the mount point (filesystem, BTRFS subvolume, etc)
    #
    #   @return [Mountable]
    storage_forward :mountable, as: "Mountable", check_with: :has_mountable

    # @!method filesystem
    #   Gets the filesystem of the mount point
    #
    #   @return [Filesystems::Base]
    storage_forward :filesystem, as: "Filesystems::Base"

    # Wheter the mount point is root
    #
    # @return [Boolean]
    def root?
      path == ROOT_PATH.to_s
    end

  protected

    def types_for_is
      super << :mount_point
    end
  end
end
