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

require "cwm/widget"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/partition_add_button"
require "y2partitioner/widgets/blk_device_edit_button"
require "y2partitioner/widgets/partition_move_button"
require "y2partitioner/widgets/device_resize_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/widgets/partitions_delete_button"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/disk_bar_graph"
require "y2partitioner/widgets/disk_device_description"

module Y2Partitioner
  module Widgets
    # A Tab for the list of partitions of a device
    class PartitionsTab < CWM::Tab
      attr_reader :device

      # Constructor
      #
      # @param device [Y2Storage::BlkDevice]
      # @param pager [CWM::TreePager]
      def initialize(device, pager, initial: false)
        textdomain "storage"

        @device = device
        @pager = pager
        @initial = initial
      end

      # @macro seeAbstractWidget
      def label
        _("&Partitions")
      end

      # @macro seeCustomWidget
      def contents
        table = ConfigurableBlkDevicesTable.new(devices, @pager)
        @contents ||= VBox(
          DiskBarGraph.new(device),
          table,
          Left(
            HBox(
              PartitionAddButton.new(device: device, short: true),
              BlkDeviceEditButton.new(pager: @pager, table: table),
              PartitionMoveButton.new(pager: @pager, table: table),
              DeviceResizeButton.new(pager: @pager, table: table),
              DeviceDeleteButton.new(pager: @pager, table: table),
              PartitionsDeleteButton.new(device: device)
            )
          )
        )
      end

    private

      def devices
        device.partitions
      end
    end
  end
end
