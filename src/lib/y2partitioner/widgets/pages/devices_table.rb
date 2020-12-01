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

require "yast/i18n"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/device_buttons_set"
require "abstract_method"

module Y2Partitioner
  module Widgets
    module Pages
      # Abstract base class for all the pages that represent a section of the
      # Partitioner consisting on a table that display all the devices of a
      # certain kind, like the page displaying all the disks, the one with all
      # the MD devices and so on.
      class DevicesTable < Base
        include Yast::I18n

        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(pager)
          textdomain "storage"

          @pager = pager
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          @table = calculate_table
          @contents = VBox(
            table,
            Left(device_buttons),
            Right(table_buttons)
          )
        end

        # @macro seeAbstractWidget
        abstract_method :label

        # @see Base
        def state_info
          { table.widget_id => table.ui_open_items }
        end

        private

        # @return [CWM::TreePager]
        attr_reader :pager

        # Devices to display in the table
        #
        # @return [Array<Y2Storage::Device>]
        abstract_method :devices

        # Table to display
        #
        # @return [Widgets::ConfigurableBlkDevicesTable]
        attr_reader :table

        # Widget representing the fixed buttons (those that do not change
        # every time the user selects a new row) displayed at the bottom of the
        # table.
        #
        # By default this returns an empty widget (i.e. no buttons).
        #
        # @return [Yast::UI::Term, CWM::AbstractWidget]
        def table_buttons
          Empty()
        end

        # @see #table
        #
        # @return [Widgets::ConfigurableBlkDevicesTable]
        def calculate_table
          ConfigurableBlkDevicesTable.new(devices, pager, device_buttons)
        end

        # Widget with the dynamic set of buttons for the selected row
        #
        # @return [DeviceButtonsSet]
        def device_buttons
          @device_buttons ||= DeviceButtonsSet.new(pager)
        end

        # Working devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def device_graph
          DeviceGraphs.instance.current
        end
      end
    end
  end
end
