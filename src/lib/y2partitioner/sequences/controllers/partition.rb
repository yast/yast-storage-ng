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

require "yast"
require "y2storage"
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Sequences
    # This class stores information about a future partition so that information
    # can be shared across the different dialogs of the process. It also takes
    # care of updating the devicegraph when needed.
    class PartitionController
      include Yast::I18n

      # @return [Y2Storage::PartitionType]
      attr_accessor :type

      # @return [:max_size,:custom_size,:custom_region]
      attr_accessor :size_choice

      # for {#size_choice} == :custom_size
      # @return [Y2Storage::DiskSize]
      attr_accessor :custom_size

      # for any {#size_choice} value this ends up with a valid value
      # @return [Y2Storage::Region]
      attr_accessor :region

      # New partition created by the controller.
      #
      # Nil if #create_partition has not beeing called or if the partition was
      # removed with #delete_partition.
      #
      # @return [Y2Storage::Partition, nil]
      attr_reader :partition

      # Name of the device being partitioned
      # @return [String]
      attr_reader :disk_name

      def initialize(disk_name)
        textdomain "storage"

        @disk_name = disk_name
      end

      # Device being partitioned
      # @return [Y2Storage::Disk]
      def disk
        dg = DeviceGraphs.instance.current
        Y2Storage::Disk.find_by_name(dg, disk_name)
      end

      # Available slots to create the partition
      # @return [Array<Y2Storage::PartitionTables::PartitionSlot>]
      def unused_slots
        # Caching seems to be important for the current dialogs to work
        @unused_slots ||= disk.ensure_partition_table.unused_partition_slots
      end

      # Creates the partition in the disk according to the controller
      # attributes (#type, #region, etc.)
      def create_partition
        ptable = disk.ensure_partition_table
        slot = ptable.unused_slot_for(region)
        @partition = ptable.create_partition(slot.name, region, type)
        UIState.instance.select_row(@partition)
      end

      # Removes the previously created partition from the disk
      def delete_partition
        return if @partition.nil?

        ptable = disk.ensure_partition_table
        ptable.delete_partition(@partition)
        @partition = nil
      end

      # Whether is possible to create any new partition in the disk
      #
      # @return [Boolean]
      def new_partition_possible?
        unused_slots.any?(&:available?)
      end

      # Title to display in the dialogs during the process
      # @return [String]
      def wizard_title
        # TRANSLATORS: dialog title. %s is a device name like /dev/sda
        _("Add Partition on %s") % disk_name
      end
    end
  end
end
