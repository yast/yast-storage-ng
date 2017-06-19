#
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "storage"
require "y2storage/devices_lists/base"
require "y2storage/devices_lists/partitions_list"
require "y2storage/devices_lists/filesystems_list"
require "y2storage/devices_lists/free_disk_spaces_list"
require "y2storage/devices_lists/encryptions_list"
require "y2storage/devices_lists/formattable"
require "y2storage/refinements/disk"

module Y2Storage
  module DevicesLists
    # List of disks from a devicegraph
    # @deprecated See DevicesList::Base
    class DisksList < Base
      list_of ::Storage::Disk
      include Formattable

      using Refinements::Disk

      # Partitions included in any of the disks
      #
      # @return [PartitionsList]
      def partitions
        part_list = list.reduce([]) { |sum, disk| sum + disk.all_partitions }
        PartitionsList.new(devicegraph, list: part_list)
      end

      # Encryption devices present in any of the disks, either directly or
      # inside a partition
      #
      # @return [FilesystemsList]
      def encryptions
        enc_list, _fs_list = with(partition_table: nil).direct_encryptions_and_filesystems
        enc_list.concat(partitions.encryptions.to_a)
        EncryptionsList.new(devicegraph, list: enc_list)
      end

      # Filesystems present in any of the disks, either directly or inside a
      # partition
      #
      # @return [FilesystemsList]
      def filesystems
        enc_list, fs_list = with(partition_table: nil).direct_encryptions_and_filesystems
        fs_list.concat(EncryptionsList.new(devicegraph, list: enc_list).filesystems.to_a)
        fs_list.concat(partitions.filesystems.to_a)
        FilesystemsList.new(devicegraph, list: fs_list)
      end

      # Free spaces in any of the disks
      #
      # @return [FreeDiskSpacesList]
      def free_disk_spaces
        spaces_list = list.reduce([]) { |sum, disk| sum + disk.free_spaces }
        FreeDiskSpacesList.new(devicegraph, list: spaces_list)
      end

      # Subset of the list filtered by both the name of the disks and the name
      # of any of its partitions.
      #
      # Very similar to the old Yast::Storage.GetDisk
      #
      # @see #with
      #
      # @param value [String, Array<String>] device name(s)
      # @return [DisksList]
      def with_name_or_partition(value)
        disks = with(name: value).to_a
        disks += partitions.with(name: value).disks.to_a
        DisksList.new(devicegraph, list: disks.uniq { |d| d.sid })
      end
    end
  end
end
