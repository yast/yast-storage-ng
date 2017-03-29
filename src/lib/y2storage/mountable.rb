require "y2storage/storage_class_wrapper"
require "y2storage/device"

module Y2Storage
  # Abstract class to represent something that can be mounted, like a filesystem
  # or a Btrfs subvolume
  #
  # This is a wrapper for Storage::Mountable
  class Mountable < Device
    include StorageClassWrapper
    wrap_class Storage::Mountable, downcast_to: ["Filesystems::Base", "BtrfsSubvolume"]

    # @!method type
    #   @return [Filesystems::Type]
    storage_forward :type, as: "Filesystems::Type"

    # @!method mount_by
    #   @return [Filesystems::MountByType]
    storage_forward :mount_by, as: "Filesystems::MountByType"

    # @!method mount_by=(new_mount_by)
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
  end
end
