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
require "y2storage/refinements/disk"

module Y2Storage
  module DevicesLists
    # List of disks from a devicegraph
    class DisksList < Base
      list_of ::Storage::Disk

      using Refinements::Disk

      # Partitions included in any of the disks
      #
      # @return [PartitionsList]
      def partitions
        part_list = list.reduce([]) { |sum, disk| sum + disk.all_partitions }
        PartitionsList.new(devicegraph, list: part_list)
      end

      # Filesystems present in any of the disks, either directly either inside a
      # partition
      #
      # @return [FilesystemsList]
      def filesystems
        fs_list = partitions.filesystems.to_a
        # Add filesystems not included in #partitions (directly on disk)
        list.each do |disk|
          next if disk.partition_table?

          begin
            fs_list << disk.filesystem if disk.filesystem
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
            # No filesystem
            nil
          end
        end
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
      # @param [String, Array<String>] device name(s)
      # @return [DisksList]
      def with_name_or_partition(value)
        disks = with(name: value).to_a
        disks += partitions.with(name: value).disks.to_a
        DisksList.new(devicegraph, list: disks.uniq { |d| d.sid })
      end
    end
  end
end
