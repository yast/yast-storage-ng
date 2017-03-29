require "y2storage/storage_class_wrapper"
require "y2storage/mountable"

module Y2Storage
  # A subvolume in a Btrfs filesystem
  #
  # This is a wrapper for Storage::BtrfsSubvolume
  class BtrfsSubvolume < Mountable
    include StorageClassWrapper
    wrap_class Storage::BtrfsSubvolume

    storage_forward :btrfs, as: "Filesystems::BlkDevice"
    alias_method :blk_filesystem, :btrfs
    alias_method :filesystem, :btrfs

    storage_forward :id
    storage_forward :top_level?
    storage_forward :top_level_btrfs_subvolume, as: "BtrfsSubvolume"
    storage_forward :path
    storage_forward :nocow?
    storage_forward :nocow=
    storage_forward :default_btrfs_subvolume?
    storage_forward :default_btrfs_subvolume=
    storage_forward :create_btrfs_subvolume, as: "BtrfsSubvolume"
  end
end
