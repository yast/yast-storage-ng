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

require "cwm/widget"
require "y2partitioner/widgets/configurable_blk_devices_table"

module Y2Partitioner
  module Widgets
    # Class to represent a tab with a list of devices beloging to
    # a specific device (raid, multipath, etc)
    class UsedDevicesTab < CWM::Tab
      # Constructor
      #
      # @param devices [Array<Y2Storage::BlkDevice>]
      # @param pager [CWM::TreePager]
      def initialize(devices, pager)
        textdomain "storage"
        @devices = devices
        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("&Used Devices")
      end

      # @macro seeCustomWidget
      def contents
        @contents ||= VBox(table)
      end

    private

      # Returns a table with all devices used by a MD raid
      #
      # @return [ConfigurableBlkDevicesTable]
      def table
        return @table unless @table.nil?
        @table = ConfigurableBlkDevicesTable.new(@devices, @pager)
        @table.show_columns(:device, :size, :format, :encrypted, :type)
        @table
      end
    end
  end
end
