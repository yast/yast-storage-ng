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
require "storage/devices_list"
require "storage/filesystems_list"

module Yast
  module Storage
    class PartitionsList < DevicesList
      list_of ::Storage::Partition

      def filesystems
        fs_list = list.map do |partition|
          begin
            partition.filesystem
          rescue ::Storage::WrongNumberOfChildren
            # No filesystem in the partition
            nil
          end
        end
        FilesystemsList.new(devicegraph, list: fs_list.compact)
      end

    protected

      def full_list
        # There is no ::Storage::Partition.all in libstorage API
        devicegraph.all_disks.to_a.reduce([]) do |sum, disk|
          if disk.partition_table
            sum + disk.partition_table.partitions.to_a
          end
        end
      end
    end
  end
end
