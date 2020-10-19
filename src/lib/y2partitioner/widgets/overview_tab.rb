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
require "y2partitioner/widgets/device_table_entry"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/disk_bar_graph"
require "y2partitioner/widgets/device_buttons_set"

module Y2Partitioner
  module Widgets
    # Base class to represent the tab that offers an overview of a device (eg. a disk)
    # and its subdevices (eg. its partitions and/or Btrfs subvolumes)
    class OverviewTab < CWM::Tab
      # @return [Y2Storage::Device]
      attr_reader :device

      # Constructor
      #
      # @param device [Y2Storage::Device]
      # @param pager [CWM::TreePager]
      def initialize(device, pager, initial: true)
        textdomain "storage"

        @device = device
        @pager = pager
        @initial = initial
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: title of the Partitioner tab that summarizes the information of a device
        _("Device &Overview")
      end

      # @macro seeCustomWidget
      def contents
        return @contents if @contents

        buttons = device_buttons
        lines = [
          bar_graph,
          table(buttons),
          Left(buttons)
        ].compact
        @contents = VBox(*lines)
      end

      private

      # All devices to show in the table, it should include the main device and
      # its relevant descendants
      #
      # @return [Array<Y2Storage::Device>]
      def devices
        [DeviceTableEntry.new_with_children(device)]
      end

      # Widget of the bar graph to display above the table
      #
      # Nil if no graph should be displayed
      def bar_graph
        return nil unless device.respond_to?(:free_spaces)

        DiskBarGraph.new(device)
      end

      # Widget of the table to display the device and its associated devices
      #
      # @param buttons_set [DeviceButtonsSet, nil] see {#device_buttons}
      def table(buttons_set)
        ConfigurableBlkDevicesTable.new(devices, @pager, buttons_set)
      end

      # Widget with the buttons set to display below the table
      #
      # Nil if no buttons set should be used
      #
      # @return [DeviceButtonsSet, nil]
      def device_buttons
        DeviceButtonsSet.new(@pager)
      end
    end
  end
end
