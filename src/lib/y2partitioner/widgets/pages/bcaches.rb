# Copyright (c) [2018-2019] SUSE LLC
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
require "y2partitioner/icons"
require "y2partitioner/ui_state"
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
      class Bcaches < CWM::Page
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
          UIState.instance.bcache_label
        end

        # @macro seeCustomWidget
        def contents
          @contents ||= VBox(
            Left(
              HBox(
                Image(icon, ""),
                Heading(label)
              )
            ),
            tabs
          )
        end

        # @macro seeAbstractWidget
        def init
          # Start always in the first tab
          tabs.switch_page(tabs.initial_page)
        end

        private

        # Page icon
        #
        # @return [String]
        def icon
          Icons::BCACHE
        end

        # Tabs to show
        #
        # @return [Array<CWM::Tab>]
        def tabs
          @tabs ||= Tabs.new(
            BcachesTab.new(@bcaches, @pager),
            BcacheCsetsTab.new(@pager)
          )
        end
      end

      # A Tab for the list of bcache devices
      class BcachesTab < CWM::Tab
        # @return [Array<Y2Storage::Bcache>]
        attr_reader :bcaches

        # @return [CWM::TreePager]
        attr_reader :pager

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
          _("Bcache Devices")
        end

        # @macro seeCustomWidget
        def contents
          @contents ||=
            VBox(
              table,
              Left(device_buttons),
              Right(table_buttons)
            )
        end

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
        # @return [Array<Y2Storage::BlkDevice>]
        def devices
          bcaches.each_with_object([]) do |bcache, devices|
            devices << bcache
            devices.concat(bcache.partitions)
          end
        end
      end

      # A Tab for the list of caching set devices
      class BcacheCsetsTab < CWM::Tab
        # @return [CWM::TreePager]
        attr_reader :pager

        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(pager)
          textdomain "storage"

          @pager = pager
        end

        # @macro seeAbstractWidget
        def label
          _("Caching Set Devices")
        end

        # @macro seeCustomWidget
        def contents
          @contents ||= VBox(table)
        end

        # Table to list all caching set devices
        #
        # @return [BcacheCsetsTable]
        def table
          @table ||= BcacheCsetsTable.new(devices, pager)
        end

        # Returns all caching set devices
        #
        # @return [Array<Y2Storage::BcacheCset>]
        def devices
          DeviceGraphs.instance.current.bcache_csets
        end
      end

      # Table for caching set devices
      class BcacheCsetsTable < ConfigurableBlkDevicesTable
        # Constructor
        #
        # @param devices [Array<Y2Storage::BcacheCsets>] see {#devices}
        # @param pager [CWM::Pager] see {#pager}
        # @param buttons_set [DeviceButtonsSet] see {#buttons_set}
        def initialize(devices, pager, buttons_set = nil)
          textdomain "storage"

          super
          show_columns(:caching_device, :size, :uuid, :used_by)
        end

        # Column label
        #
        # @return [String]
        def caching_device_title
          # TRANSLATORS: table column label.
          _("Caching Device")
        end

        # Column label
        #
        # @return [String]
        def uuid_title
          # TRANSLATORS: table column label.
          _("UUID")
        end

        # Column label
        #
        # @return [String]
        def used_by_title
          # TRANSLATORS: table column label.
          _("Used By")
        end

        # Column value
        #
        # @param device [Y2Storage::BcacheCset]
        # @return [String] e.g., "/dev/sda1"
        def caching_device_value(device)
          device.blk_devices.first.name
        end

        # Column value
        #
        # @param device [Y2Storage::BcacheCset]
        # @return [String] e.g., "2.00 GiB"
        def size_value(device)
          device.blk_devices.first.size.to_human_string
        end

        # Column value
        #
        # @param device [Y2Storage::BcacheCset]
        # @return [String] e.g., "111222333-444-55"
        def uuid_value(device)
          device.uuid
        end

        # Column value
        #
        # @param device [Y2Storage::BcacheCset]
        # @return [String] e.g., "/dev/bcache0, /dev/bcache1"
        def used_by_value(device)
          device.bcaches.map(&:name).join(", ")
        end
      end
    end
  end
end
