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
require "storage/partitions_list"
require "storage/filesystems_list"
#require "storage/free_disk_spaces_list"
require "storage/refinements/disk"

module Yast
  module Storage
    class DisksList < DevicesList
      list_of ::Storage::Disk
      by_default_delegate_to :partitions

      using Refinements::Disk

      def partitions
        part_list = list.reduce([]) { |sum, disk| sum + disk.all_partitions }
        PartitionsList.new(devicegraph, list: part_list)
      end

      def filesystems
        fs_list = partitions.filesystems.to_a
        # Add filesystems not included in #partitions (directly on disk)
        list.each do |disk|
          fs_list << disk.filesystem if !disk.partition_table && disk.filesystem
        end
        FilesystemsList.new(devicegraph, list: fs_list)
      end

      def free_disk_spaces
        spaces_list = list.reduce([]) { |sum, disk| sum + disk.free_spaces }
        FreeDiskSpacesList.new(devicegraph, list: spaces_list)
      end
    end
  end
end
