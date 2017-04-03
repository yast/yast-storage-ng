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
require "y2storage/partition_tables"

module Y2Storage
  # Base class for all the devices that can contain a partition table, like
  # disks or RAID devices
  #
  # This is a wrapper for Storage::Partitionable
  class Partitionable < BlkDevice
    wrap_class Storage::Partitionable, downcast_to: ["Disk"]

    storage_forward :range
    storage_forward :range=
    storage_forward :default_partition_table_type, as: "PartitionTables::Type"
    storage_forward :possible_partition_table_types, as: "PartitionTables::Type"
    storage_forward :create_partition_table, as: "PartitionTables::Base"
    storage_forward :partition_table, as: "PartitionTables::Base"
    storage_forward :topology

    storage_class_forward :all, as: "Partitionable"

    # Minimal grain of the partitionable
    # TODO: provide a good definition for "grain"
    #
    # @return [DiskSize]
    def min_grain
      DiskSize.new(topology.minimal_grain)
    end

    # Partitions in the device
    #
    # @return [Array<Partition>]
    def partitions
      partition_table ? partition_table.partitions : []
    end

    # Checks whether it contains a GUID partition table
    #
    # @return [Boolean]
    def gpt?
      return false unless partition_table
      partition_table.type.to_sym == :gpt
    end

    # Checks whether a name matches the device or any of its partitions
    #
    # @param name [String] device name
    # @return [Boolean]
    def name_or_partition?(name)
      return true if self.name == name

      partitions.any? { |part| part.name == name }
    end

    # Partitionable device matching the name or partition name
    #
    # @param devicegraph [Devicegraph] where to search
    # @param name [String] device name
    # @return [Partitionable] nil if there is no match
    def self.find_by_name_or_partition(devicegraph, name)
      all(devicegraph).detect { |dev| dev.name_or_partition?(name) }
    end
  end
end
