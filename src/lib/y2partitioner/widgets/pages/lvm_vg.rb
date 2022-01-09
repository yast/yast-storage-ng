# Copyright (c) [2017-2020] SUSE LLC
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

require "y2partitioner/widgets/pages/tabbed"
require "y2partitioner/widgets/overview_tab"
require "y2partitioner/widgets/used_devices_tab"
require "y2partitioner/widgets/lvm_devices_table"
require "y2partitioner/widgets/lvm_vg_bar_graph"
require "y2partitioner/widgets/device_buttons_set"
require "y2partitioner/widgets/lvm_buttons"
require "y2partitioner/widgets/columns"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a LVM Volume Group. It contains several tabs.
      class LvmVg < Tabbed
        # Constructor
        #
        # @param lvm_vg [Y2Storage::Lvm_vg]
        # @param pager [CWM::TreePager]
        def initialize(lvm_vg, pager)
          super()
          textdomain "storage"

          @lvm_vg = lvm_vg
          @pager = pager
          self.widget_id = "lvm_vg:" + lvm_vg.vg_name
        end

        # @return [Y2Storage::LvmVg] volume group the page is about
        def device
          @lvm_vg
        end

        # @macro seeAbstractWidget
        def label
          @lvm_vg.vg_name
        end

        private

        # @see Tabbed
        def calculate_tabs
          [
            LvmVgTab.new(@lvm_vg, @pager),
            LvmPvTab.new(@lvm_vg, @pager)
          ]
        end

        # @return [String]
        def section
          Lvm.label
        end
      end

      # A Tab for the LVM volume group and its subdevices (eg. logical volumes)
      class LvmVgTab < OverviewTab
        private

        # Returns a table with all logical volumes of a volume group, including
        # thin pools and thin volumes
        #
        # @see #devices
        #
        # @param buttons_set [DeviceButtonsSet]
        # @return [LvmDevicesTable]
        def calculate_table(buttons_set)
          LvmDevicesTable.new(devices, @pager, buttons_set)
        end

        # Bar graph representing the volume group
        #
        # @return [LvmBarGraph]
        def calculate_bar_graph
          LvmVgBarGraph.new(device)
        end
      end

      # A Tab for the LVM physical volumes of a volume group
      class LvmPvTab < UsedDevicesTab
        # @see UsedDevicesTab#label
        def label
          _("&Physical Volumes")
        end

        # @see UsedDevicesTab#used_devices
        def used_devices
          device.lvm_pvs.map(&:plain_blk_device)
        end

        # @see UsedDevicesTab#buttons
        def buttons
          Right(LvmVgResizeButton.new(device: device))
        end
      end
    end
  end
end
