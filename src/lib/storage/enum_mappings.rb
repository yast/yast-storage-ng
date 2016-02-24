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

module Yast
  module Storage
    #
    # Mappings from string to libstorage-ng enums.
    # This is used for reading and writing YaML files for device trees.
    #
    module EnumMappings

      PARTITION_TABLE_TYPES =
      {
        "loop"   => ::Storage::PtType_PT_LOOP,
        "msdos"  => ::Storage::PtType_MSDOS,
        "gpt"    => ::Storage::PtType_GPT,
        "dasd"   => ::Storage::PtType_DASD,
        "mac"    => ::Storage::PtType_MAC
      }

      PARTITION_TYPES =
      {
        "primary"  => ::Storage::PRIMARY,
        "extended" => ::Storage::EXTENDED,
        "logical"  => ::Storage::LOGICAL
      }

      PARTITION_IDS =
      {
        "dos12"       => ::Storage::ID_DOS12,       #  0x01
        "dos16"       => ::Storage::ID_DOS16,       #  0x06
        "dos32"       => ::Storage::ID_DOS32,       #  0x0c
        "ntfs"        => ::Storage::ID_NTFS,        #  0x07
        "extended"    => ::Storage::ID_EXTENDED,    #  0x0f
        "ppc_prep"    => ::Storage::ID_PPC_PREP,    #  0x41
        "linux"       => ::Storage::ID_LINUX,       #  0x83
        "swap"        => ::Storage::ID_SWAP,        #  0x82
        "lvm"         => ::Storage::ID_LVM,         #  0x8e
        "raid"        => ::Storage::ID_RAID,        #  0xfd
        "apple_other" => ::Storage::ID_APPLE_OTHER, #  0x101
        "apple_hfs"   => ::Storage::ID_APPLE_HFS,   #  0x102
        "gpt_boot"    => ::Storage::ID_GPT_BOOT,    #  0x103
        "gpt_service" => ::Storage::ID_GPT_SERVICE, #  0x104
        "gpt_msftres" => ::Storage::ID_GPT_MSFTRES, #  0x105
        "apple_ufs"   => ::Storage::ID_APPLE_UFS,   #  0x106
        "gpt_bios"    => ::Storage::ID_GPT_BIOS,    #  0x107
        "gpt_prep"    => ::Storage::ID_GPT_PREP     #  0x108
      }

      FILE_SYSTEM_TYPES =
      {
        "reiserfs" => ::Storage::REISERFS,
        "ext2"     => ::Storage::EXT2,
        "ext3"     => ::Storage::EXT3,
        "ext4"     => ::Storage::EXT4,
        "btrfs"    => ::Storage::BTRFS,
        "vfat"     => ::Storage::VFAT,
        "xfs"      => ::Storage::XFS,
        "jfs"      => ::Storage::JFS,
        "hfs"      => ::Storage::HFS,
        "ntfs"     => ::Storage::NTFS,
        "swap"     => ::Storage::SWAP,
        "hfsplus"  => ::Storage::HFSPLUS,
        "nfs"      => ::Storage::NFS,
        "nfs4"     => ::Storage::NFS4,
        "tmpfs"    => ::Storage::TMPFS,
        "iso9660"  => ::Storage::ISO9660,
        "udf"      => ::Storage::UDF
      }
    end
  end
end
