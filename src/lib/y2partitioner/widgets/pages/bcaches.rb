# Copyright (c) [2018-2020] SUSE LLC
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

require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/bcache_add_button"
require "y2partitioner/widgets/device_buttons_set"
require "y2partitioner/widgets/configurable_blk_devices_table"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for bcache devices
      #
      # It contains two tabs: one tab with a list of bcache devices and another
      # tab with the list of caching sets.
      class Bcaches < Base
        extend Yast::I18n

        textdomain "storage"

        # Label for all the instances
        #
        # @see #label
        #
        # @return [String]
        def self.label
          _("Bcache Devices")
        end

        # Constructor
        #
        # @param bcaches [Array<Y2Storage::Bcache>]
        # @param pager [CWM::TreePager]
        def initialize(bcaches, pager)
          textdomain "storage"

          @bcaches = bcaches
          @pager = pager
        end

        # @macro seeAbstractWidget
        def label
          self.class.label
        end

        # @macro seeCustomWidget
        def contents
          @contents ||= Top(
            VBox(
              Left(
                VBox(
                  table,
                  Left(device_buttons),
                  Right(table_buttons)
                )
              )
            )
          )
        end

        private

        # @return [Array<Y2Storage::Bcache>]
        attr_reader :bcaches

        # @return [CWM::TreePager]
        attr_reader :pager

        # Table to list all bcache devices and their partitions
        #
        # @return [Widgets::ConfigurableBlkDevicesTable]
        def table
          @table ||= ConfigurableBlkDevicesTable.new(devices, pager, device_buttons)
        end

        # Widget with the dynamic set of buttons for the selected row
        #
        # @return [DeviceButtonsSet]
        def device_buttons
          @device_buttons ||= DeviceButtonsSet.new(pager)
        end

        # @see DevicesTable
        def table_buttons
          BcacheAddButton.new
        end

        # Returns all bcache devices and their partitions
        #
        # @return [Array<DeviceTableEntry>]
        def devices
          bcaches.map do |bcache|
            DeviceTableEntry.new_with_children(bcache)
          end
        end
      end
    end
  end
end
