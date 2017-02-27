#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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

require "yast"
require "storage"

module Y2Storage
  #
  # Mappings from string to libstorage-ng enums.
  # This is used for reading and writing YAML files for device trees.
  #
  module EnumMappings
    PARTITION_TABLE_TYPES =
      {
        "loop"  => ::Storage::PtType_PT_LOOP,
        "msdos" => ::Storage::PtType_MSDOS,
        "gpt"   => ::Storage::PtType_GPT,
        "dasd"  => ::Storage::PtType_DASD,
        "mac"   => ::Storage::PtType_MAC
      }

    PARTITION_TYPES =
      {
        "primary"  => ::Storage::PartitionType_PRIMARY,
        "extended" => ::Storage::PartitionType_EXTENDED,
        "logical"  => ::Storage::PartitionType_LOGICAL
      }

    PARTITION_IDS =
      {
        "dos12"              => ::Storage::ID_DOS12,              #  0x01
        "dos16"              => ::Storage::ID_DOS16,              #  0x06
        "dos32"              => ::Storage::ID_DOS32,              #  0x0c
        "ntfs"               => ::Storage::ID_NTFS,               #  0x07
        "extended"           => ::Storage::ID_EXTENDED,           #  0x0f
        "prep"               => ::Storage::ID_PREP,               #  0x41
        "linux"              => ::Storage::ID_LINUX,              #  0x83
        "swap"               => ::Storage::ID_SWAP,               #  0x82
        "lvm"                => ::Storage::ID_LVM,                #  0x8e
        "raid"               => ::Storage::ID_RAID,               #  0xfd
        "unknown"            => ::Storage::ID_UNKNOWN,
        "bios_boot"          => ::Storage::ID_BIOS_BOOT,
        "windows_basic_data" => ::Storage::ID_WINDOWS_BASIC_DATA,
        "microsoft_reserved" => ::Storage::ID_MICROSOFT_RESERVED
      }

    FILE_SYSTEM_TYPES =
      {
        "reiserfs" => ::Storage::FsType_REISERFS,
        "ext2"     => ::Storage::FsType_EXT2,
        "ext3"     => ::Storage::FsType_EXT3,
        "ext4"     => ::Storage::FsType_EXT4,
        "btrfs"    => ::Storage::FsType_BTRFS,
        "vfat"     => ::Storage::FsType_VFAT,
        "xfs"      => ::Storage::FsType_XFS,
        "jfs"      => ::Storage::FsType_JFS,
        "hfs"      => ::Storage::FsType_HFS,
        "ntfs"     => ::Storage::FsType_NTFS,
        "swap"     => ::Storage::FsType_SWAP,
        "hfsplus"  => ::Storage::FsType_HFSPLUS,
        "nfs"      => ::Storage::FsType_NFS,
        "tmpfs"    => ::Storage::FsType_TMPFS,
        "iso9660"  => ::Storage::FsType_ISO9660,
        "udf"      => ::Storage::FsType_UDF
      }

    ALIGN_POLICIES =
      {
        "align_end" => ::Storage::AlignPolicy_ALIGN_END,
        "keep_end"  => ::Storage::AlignPolicy_KEEP_END,
        "keep_size" => ::Storage::AlignPolicy_KEEP_SIZE
      }

    ENCRYPTION_TYPES =
      {
        "twofish"        => ::Storage::EncryptionType_TWOFISH,
        "twofish_old"    => ::Storage::EncryptionType_TWOFISH_OLD,
        "twofish256_old" => ::Storage::EncryptionType_TWOFISH256_OLD,
        "luks"           => ::Storage::EncryptionType_LUKS
      }
  end
end
