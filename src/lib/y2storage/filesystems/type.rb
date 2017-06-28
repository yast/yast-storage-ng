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

require "y2storage/storage_enum_wrapper"

module Y2Storage
  module Filesystems
    # Class to represent all the possible filesystem types
    #
    # This is a wrapper for the Storage::FsType enum
    class Type
      include StorageEnumWrapper

      wrap_enum "FsType"

      PROPERTIES = {
        btrfs:    {
          name: "BtrFS"
        },
        ext2:     {
          name: "Ext2"
        },
        ext3:     {
          name: "Ext3"
        },
        ext4:     {
          name: "Ext4"
        },
        hfs:      {
          name: "MacHFS"
        },
        hfsplus:  {
          name: "MacHFS+"
        },
        jfs:      {
          name: "JFS"
        },
        msdos:    {
          name: "FAT"
        },
        nfs:      {
          name: "NFS"
        },
        nfs4:     {
          name: "NFS4"
        },
        nilfs2:   {
          name: "NilFS"
        },
        ntfs:     {
          name: "NTFS"
        },
        reiserfs: {
          name: "Reiser"
        },
        swap:     {
          name: "Swap"
        },
        vfat:     {
          name: "FAT"
        },
        xfs:      {
          name: "XFS"
        },
        iso9660:  {
          name: "ISO9660"
        },
        udf:      {
          name: "UDF"
        }
      }

      ROOT_FILESYSTEMS = [:ext2, :ext3, :ext4, :btrfs, :reiserfs, :xfs]

      HOME_FILESYSTEMS = [:ext2, :ext3, :ext4, :btrfs, :reiserfs, :xfs]

      private_constant :PROPERTIES, :ROOT_FILESYSTEMS, :HOME_FILESYSTEMS

      # Allowed filesystems for root
      #
      # @return [Array<Filesystems::Type>]
      def self.root_filesystems
        ROOT_FILESYSTEMS.map { |f| find(f) }
      end

      # Allowed filesystems for home
      #
      # @return [Array<Filesystems::Type>]
      def self.home_filesystems
        HOME_FILESYSTEMS.map { |f| find(f) }
      end

      # Check if filesystem is usable as root (mountpoint "/") filesystem.
      #
      # return [Boolean]
      #
      # @example
      #   devicegraph.filesystems.each do |fs|
      #     puts "#{fs.type}: #{fs.type.root_ok?}"
      #   end
      #
      def root_ok?
        return Type.root_filesystems.include?(self)
      end

      # Check if filesystem is usable as home (mountpoint "/home") filesystem.
      #
      # return [Boolean]
      #
      # @example
      #   devicegraph.filesystems.each do |fs|
      #     puts "#{fs.type}: #{fs.type.home_ok?}"
      #   end
      #
      def home_ok?
        return Type.home_filesystems.include?(self)
      end

      # Human readable text for a filesystem
      #
      # @return [String]
      def to_human_string
        default = to_s
        properties = PROPERTIES[to_sym]
        return default unless properties
        properties[:name] || default
      end

      # for backward compatibility
      # @method to_human
      #   @deprecated use to_human_string instead
      alias_method :to_human, :to_human_string
    end
  end
end
