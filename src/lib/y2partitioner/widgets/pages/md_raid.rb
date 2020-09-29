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

require "y2partitioner/widgets/tabs"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/pages/md_raids"
require "y2partitioner/widgets/used_devices_tab"
require "y2partitioner/widgets/used_devices_edit_button"
require "y2partitioner/widgets/overview_tab"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a md raid device: contains {MdTab} and {MdUsedDevicesTab}
      class MdRaid < Base
        # Constructor
        #
        # @param md [Y2Storage::Md]
        # @param pager [CWM::TreePager]
        def initialize(md, pager)
          textdomain "storage"

          @md = md
          @pager = pager
          self.widget_id = "md:" + @md.name
        end

        # @return [Y2Storage::Md] RAID the page is about
        def device
          @md
        end

        # @macro seeAbstractWidget
        def label
          @md.basename
        end

        # @macro seeCustomWidget
        def contents
          Top(
            VBox(
              Left(
                Tabs.new(
                  MdTab.new(@md, @pager, initial: true),
                  MdUsedDevicesTab.new(@md, @pager)
                )
              )
            )
          )
        end

        private

        # @return [String]
        def section
          MdRaids.label
        end
      end

      # A Tab for a Software RAID description
      class MdTab < OverviewTab
        private

        def devices
          [device] + device.partitions
        end
      end

      # A Tab for the used devices of a MD RAID
      class MdUsedDevicesTab < UsedDevicesTab
        # @see UsedDevicesTab#used_devices
        def used_devices
          device.devices
        end

        # @see UsedDevicesTab#buttons
        def buttons
          Right(UsedDevicesEditButton.new(device: device))
        end
      end
    end
  end
end
