# Copyright (c) [2020] SUSE LLC
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
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/disk_bar_graph"
require "y2partitioner/widgets/device_buttons_set"

module Y2Partitioner
  module Widgets
    # A Tab for the list of partitions of a device
    class OverviewTab < CWM::Tab
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
        _("Device &Overview")
      end

      # @macro seeCustomWidget
      def contents
        return @contents if @contents

        device_buttons = DeviceButtonsSet.new(@pager)
        table = ConfigurableBlkDevicesTable.new(devices, @pager, device_buttons)
        lines = device.respond_to?(:free_spaces) ? [DiskBarGraph.new(device)] : []
        lines += [
          table,
          Left(device_buttons)
        ]
        @contents = VBox(*lines)
      end

      private

      def devices
        [device]
      end
    end
  end
end
