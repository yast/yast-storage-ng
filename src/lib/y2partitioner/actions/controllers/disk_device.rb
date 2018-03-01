# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2storage"
require "y2partitioner/device_graphs"

Yast.import "Mode"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores needed information to perform certain actions over a disk device,
      # for example, the disks over which to clone the device. It also takes care of
      # updating the devicegraph when needed.
      class DiskDevice
        # Current disk device
        #
        # @return [Y2Storage::BlkDevice] a disk device
        attr_reader :device

        # @return [Array<Y2Storage::Partitionable>]
        attr_accessor :selected_devices_for_cloning

        # Constructor
        #
        # @raise [TypeError] if device is not a disk device.
        #
        # @param device [Y2Storage::BlkDevice] it has to be a disk device,
        #   (i.e., device#is?(:disk_device) #=> true).
        def initialize(device)
          raise(TypeError, "param device has to be a disk device") unless device.is?(:disk_device)

          @device = device
          @selected_devices_for_cloning = []
        end

        # Whether the current device has a partition table
        #
        # @return [Boolean]
        def partition_table?
          !device.partition_table.nil?
        end

        # Whether there are suitable devices where to clone the current device
        #
        # @return [Boolean]
        def suitable_devices_for_cloning?
          !suitable_devices_for_cloning.empty?
        end

        # Suitable devices where to clone the current device
        #
        # @note MD RAID can be partitioned, but only disk devices are taking into account
        #   as possible devices where to clone.
        #
        # @return [Array<Y2Storage::Partitionable>]
        def suitable_devices_for_cloning
          @suitable_devices ||= working_graph.disk_devices.select { |d| suitable_for_cloning?(d) }
        end

        # Clones the current device into the target device
        #
        # @note Target device is wiped before cloning into it.
        #
        # @param target_device [Y2Storage::Partitionable]
        def clone_to_device(target_device)
          wipe_device(target_device)
          clone_partition_table(target_device)
        end

      private

        # Current devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def working_graph
          DeviceGraphs.instance.current
        end

        # Whether the current device can be cloned into the target device
        #
        # @note A target device is suitable for cloning if it has enough size, it supports
        #   the partition table type of the the current device, and it has the same
        #   topology than the current device. Also note that in a running system, a device
        #   holding mount points cannot be used as device for cloning. Self cloning is
        #   also avoided.
        #
        # @param target_device [Y2Storage::Partitionable] device where to clone
        # @return [Boolean]
        def suitable_for_cloning?(target_device)
          return false if self_cloning?(target_device)

          suitable =
            enough_size_for_cloning?(target_device) &&
            support_partition_table_type?(target_device) &&
            same_topology?(target_device)

          Yast::Mode.installation ? suitable : suitable && !mount_points?(target_device)
        end

        # Whether it is trying a self cloning
        #
        # @note A device cannot be self cloned.
        #
        # @param target_device [Y2Storage::Partitionable] device where to clone
        # @return [Boolean]
        def self_cloning?(target_device)
          target_device.sid == device.sid
        end

        # Whether the target device has enough size for the cloning
        #
        # @param target_device [Y2Storage::Partitionable] device where to clone
        # @return [Boolean]
        def enough_size_for_cloning?(target_device)
          target_device.size >= device.size
        end

        # Whether the target device supports the partition table type of the current device
        #
        # @param target_device [Y2Storage::Partitionable] device where to clone
        # @return [Boolean]
        def support_partition_table_type?(target_device)
          target_device.possible_partition_table_types.include?(device.partition_table.type)
        end

        # Whether the target device has the same topology than the current device
        #
        # @param target_device [Y2Storage::Partitionable] device where to clone
        # @return [Boolean]
        def same_topology?(target_device)
          target_device.topology == device.topology
        end

        # Whether the target device holds mount points
        #
        # @note If something mounted depends on the target device, that device cannot be
        #   used for cloning. Firstly, mount points should be removed.
        #
        # @param target_device [Y2Storage::Partitionable] device where to clone
        # @return [Boolean]
        def mount_points?(target_device)
          target_device.descendants.any? { |d| d.is?(:mount_point) }
        end

        # Wipes the target device
        #
        # @note All its descendats are removed.
        #
        # @param target_device [Y2Storage::BlkDevice]
        def wipe_device(target_device)
          target_device.remove_descendants
        end

        # Clones the partition table of the current device into the target device
        #
        # @note All partitions of the current device are cloned into the target
        #   device, see {#clone_partition}.
        #
        # @param target_device [Y2Storage::Partitionable] device where to clone
        def clone_partition_table(target_device)
          target_device.create_partition_table(device.partition_table.type)
          sorted_partitions = device.partitions.sort_by(&:name)
          sorted_partitions.each { |p| clone_partition(target_device, p) }
        end

        # Clones a partition into the target device
        #
        # @note Cloned partition will have a region and partition id equal to the given
        #   partition. Note that LUKS, filesystems and other stuff are not cloned.
        #   Correspondence between partition names and regions is also kept.
        def clone_partition(target_device, partition)
          name = target_device.partition_table.unused_partition_slots.first.name
          partition_table = target_device.partition_table
          new_partition = partition_table.create_partition(name, partition.region, partition.type)
          new_partition.id = partition.id
        end
      end
    end
  end
end
