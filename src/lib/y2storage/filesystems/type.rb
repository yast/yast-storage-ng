require "y2storage/storage_enum_wrapper"

module Y2Storage
  module Filesystems
    class Type
      include StorageEnumWrapper

      wrap_enum "Storage::FsType", names: [
        :reiserfs, :ext2, :ext3, :ext4, :btrfs, :vfat, :xfs, :jfs, :hfs, :ntfs,
        :swap, :hfsplus, :nfs, :nfs4, :tmpfs, :iso9660, :udf
      ]
    end
  end
end
