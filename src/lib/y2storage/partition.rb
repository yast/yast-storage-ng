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

require "y2storage/storage_class_wrapper"
require "y2storage/blk_device"
require "y2storage/disk"

module Y2Storage
  # A partition in a partitionable device (like a disk or RAID)
  #
  # This is a wrapper for Storage::Partition
  class Partition < BlkDevice
    wrap_class Storage::Partition

    storage_forward :number
    storage_forward :partition_table, as: "PartitionTables::Base"
    storage_forward :partitionable, as: "Partitionable"
    storage_forward :type, as: "PartitionType"
    storage_forward :type=
    storage_forward :id, as: "PartitionId"
    storage_forward :id=
    storage_forward :boot?
    storage_forward :boot=
    storage_forward :legacy_boot?
    storage_forward :legacy_boot=

    storage_class_forward :create, as: "Partition"
    storage_class_forward :find_by_name, as: "Partition"

    def disk
      partitionable.is_a?(Disk) ? partitionable : nil
    end

    def self.all(devicegraph)
      Partitionable.all(devicegraph).map(&:partitions).flatten
    end

    def inspect
      "<Partition #{name} #{size}, #{region.show_range}>"
    end
  end
end
