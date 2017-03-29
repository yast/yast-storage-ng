require "y2storage/storage_class_wrapper"

module Y2Storage
  # An abstract base class of storage devices and a vertex in the Devicegraph.
  #
  # The Device class does not have a device name since some device types do
  # not have a intrinsic device name, e.g. btrfs.
  #
  # This is a wrapper for Storage::Device
  class Device
    include StorageClassWrapper
    wrap_class Storage::Device,
      downcast_to: ["BlkDevice", "Mountable", "PartitionTables::Base"]

    storage_forward :==
    storage_forward :!=
    storage_forward :sid
    storage_forward :ancestors, as: "Device"
    storage_forward :exists_in_devicegraph?
    storage_forward :exists_in_probed?
    storage_forward :exists_in_staging?
    storage_forward :displayname
    storage_forward :detect_resize_info
    storage_forward :remove_descendants
    storage_forward :userdata
    storage_forward :userdata=

    # Checks where the device is a disk
    #
    # @return [Boolean] true if this is a Y2Storage::Disk
    def disk?
      is_a?(Disk)
    end

    # Checks where the device is a partition
    #
    # @return [Boolean] true if this is a Y2Storage::Partition
    def partition?
      is_a?(Partition)
    end

    # Checks where the device is an encryption device
    #
    # @return [Boolean] true if this is a Y2Storage::Encryption
    def encryption?
      is_a?(Encryption)
    end

    # Checks where the device is a filesystem
    #
    # @return [Boolean] true if this is a Y2Storage::Filesystems::Base
    def filesystem?
      is_a?(Filesystems::Base)
    end

    # Checks where the device is a block filesystem
    #
    # @return [Boolean] true if this is a Y2Storage::Filesystems::BlkFilesystem
    def blk_filesystem?
      is_a?(Filesystems::BlkFilesystem)
    end

    # Checks where the device is a Btrfs subvolume
    #
    # @return [Boolean] true if this is a Y2Storage::BtrfsSubvolume
    def btrfs_subvolume?
      is_a?(BtrfsSubvolume)
    end

    # Checks where the device is a NFS mount
    #
    # @return [Boolean] true if this is a Y2Storage::Nfs
    def nfs?
      is_a?(Nfs)
    end

    # Checks where the device is a LVM volume group
    #
    # @return [Boolean] true if this is a Y2Storage::LvmVg
    def lvm_vg?
      is_a?(LvmVg)
    end

    # Checks where the device is a LVM physical volume
    #
    # @return [Boolean] true if this is a Y2Storage::LvmPv
    def lvm_pv?
      is_a?(LvmPv)
    end

    # Checks where the device is a LVM logical volume
    #
    # @return [Boolean] true if this is a Y2Storage::LvmLv
    def lvm_lv?
      is_a?(LvmLv)
    end
  end
end
