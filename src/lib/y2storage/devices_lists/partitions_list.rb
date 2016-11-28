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
require "y2storage/devices_lists/filesystems_list"

module Y2Storage
  module DevicesLists
    # List of partitions from a devicegraph
    class PartitionsList < Base
      list_of ::Storage::Partition

      # Filesystems located in the partitions
      #
      # @return [FilesystemsList]
      def filesystems
        fs_list = list.map do |partition|
          begin
            partition.filesystem
          rescue Storage::WrongNumberOfChildren
            # No filesystem in the partition
            nil
          end
        end
        FilesystemsList.new(devicegraph, list: fs_list.compact)
      end

      # Disks containing the partitions
      #
      # @return [DisksList]
      def disks
        disks = list.map { |partition| Storage.to_disk(partition.partitionable) }
        disks.uniq! { |s| s.sid }
        DisksList.new(devicegraph, list: disks)
      end

    protected

      def full_list
        # There is no ::Storage::Partition.all in libstorage API
        devicegraph.all_disks.to_a.reduce([]) do |sum, disk|
          begin
            sum + disk.partition_table.partitions.to_a
          rescue Storage::WrongNumberOfChildren
            # No partition table
            sum
          end
        end
      end
    end
  end
end
