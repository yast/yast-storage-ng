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

require "y2partitioner/widgets/tabs"
require "y2partitioner/widgets/overview_tab"
require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/pages/bcaches"
require "y2partitioner/widgets/used_devices_tab"
require "y2partitioner/widgets/bcache_edit_button"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a bcache device
      class Bcache < Base
        # @return [Y2Storage::Bcache] Device this page is about
        attr_reader :bcache
        alias_method :device, :bcache

        # Constructor
        #
        # @param bcache [Y2Storage::Bcache]
        # @param pager [CWM::TreePager]
        def initialize(bcache, pager)
          textdomain "storage"

          @bcache = bcache
          @pager = pager
          self.widget_id = "bcache:" + bcache.name
        end

        # @macro seeAbstractWidget
        def label
          device.basename
        end

        # @macro seeCustomWidget
        def contents
          Top(
            VBox(
              Left(
                Tabs.new(
                  BcacheTab.new(device, @pager),
                  BcacheUsedDevicesTab.new(device, @pager)
                )
              )
            )
          )
        end

        private

        # @return [String]
        def section
          Bcaches.label
        end
      end

      # A Tab for a Bcache description and its buttons
      class BcacheTab < OverviewTab
        private

        def devices
          [
            BlkDevicesTable::DeviceTree.new(device, children: device.partitions)
          ]
        end
      end

      # A Tab for the used devices of a Bcache
      class BcacheUsedDevicesTab < UsedDevicesTab
        # @see UsedDevicesTab#used_devices
        def used_devices
          ([device.backing_device] + device.bcache_cset.blk_devices).compact
        end

        # @see UsedDevicesTab#buttons
        def buttons
          Right(BcacheEditButton.new(device: device))
        end
      end
    end
  end
end
