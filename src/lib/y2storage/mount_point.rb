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

    # @return [Symbol] Filesystem types which should use some value
    #   (other than 0) in the fs_passno field
    TYPES_WITH_PASSNO = [:ext2, :ext3, :ext4, :jfs].freeze
    private_constant :TYPES_WITH_PASSNO

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

    storage_forward :storage_path=, to: :path=
    private :storage_path=

    # Sets the value for {#path} and ensures {#passno} has a value consistent
    # with the new path
    #
    # @param path [String]
    # @raise [Storage::InvalidMountPointPath] if trying to set an invalid path
    def path=(path)
      self.storage_path = path

      to_storage_value.passno =
        if passno_must_be_set?
          root? ? 1 : 2
        else
          0
        end
    end

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
      options&.each { |o| to_storage_value.mount_options << o }
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

    # @!attribute mount_type
    #   Filesystem type used to mount the device, as specified in fstab and/or
    #   in the mount command.
    #
    #   @return [Filesystems::Type]
    storage_forward :mount_type, as: "Filesystems::Type"
    storage_forward :mount_type=

    # @!method in_etc_fstab?
    #   Whether the mount point is present (probed devicegraph) or
    #   will be present (staging devicegraph) in /etc/fstab
    #
    #   @return [Boolean]
    storage_forward :in_etc_fstab?

    # @!method active?
    #   Whether the mount point is mounted (probed devicegraph) or
    #   should be mounted (staging devicegraph)
    #
    #   @return [Boolean]
    storage_forward :active?

    # @!method active=(value)
    #
    #   Sets the {#active?} flag
    #
    #   @param value [Boolean]
    storage_forward :active=

    # @!method immediate_deactivate
    #   Immediately deactivates (unmount) the mount point object. In
    #   contrast to {#active=} this function acts immediately and does
    #   not require calling to commit.
    #
    #   @note The mount point object must exist in the probed devicegraph.
    #
    #   @raise [Storage::Exception] when it cannot be unmounted.
    storage_forward :immediate_deactivate

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

    # @!method passno
    #   Value for the fs_passno field for fstab(5). The passno field is used by
    #   the fsck(8) program to determine the order in which filesystem checks
    #   are done at reboot time.
    #
    #   @return [Integer]
    storage_forward :passno

    # @!method freq
    #   Value for the fs_freq field for fstab(5). The freq field is used by the
    #   dump(8) command to determine which filesystems need to be dumped. The
    #   field is likely obsolete.
    #
    #   @return [Integer]
    storage_forward :freq

    # Whether the mount point is root
    #
    # @return [Boolean]
    def root?
      path == ROOT_PATH.to_s
    end

    # @see Device#in_etc?
    # @see #in_etc_fstab
    def in_etc?
      in_etc_fstab?
    end

    # Whether the given path is equivalent to {#path}
    #
    # This method is more robust than a simple string comparison, since it takes
    # into account trailing slashes and similar potential problems.
    #
    # @param other_path [String, Pathname]
    # @return [Boolean]
    def path?(other_path)
      Pathname.new(other_path).cleanpath == Pathname.new(path).cleanpath
    end

    protected

    def types_for_is
      super << :mount_point
    end

    # Whether a non-zero {#passno} makes sense for this mount point
    #
    # @return [Boolean]
    def passno_must_be_set?
      return false unless mountable&.is?(:filesystem)

      filesystem.type.is?(*TYPES_WITH_PASSNO)
    end
  end
end
