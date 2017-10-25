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
require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/md_description"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/edit_blk_device_button"
require "y2partitioner/widgets/used_devices_tab"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a md raid device: contains {MdTab} and {UsedDevicesTab}
      class MdRaid < CWM::Page
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
          icon = Icons.small_icon(Icons::RAID)
          VBox(
            Left(
              HBox(
                Image(icon, ""),
                Heading(format(_("RAID: %s"), @md.name))
              )
            ),
            Tabs.new(
              MdTab.new(@md),
              UsedDevicesTab.new(@md.devices, @pager)
            )
          )
        end
      end

      # A Tab for a Md raid description
      class MdTab < CWM::Tab
        # Constructor
        #
        # @param md [Y2Storage::Md]
        def initialize(md)
          textdomain "storage"
          @md = md
        end

        def initial
          true
        end

        # @macro seeAbstractWidget
        def label
          _("&Overview")
        end

        # @macro seeCustomWidget
        def contents
          # Page wants a WidgetTerm, not an AbstractWidget
          @contents ||=
            VBox(
              MdDescription.new(@md),
              Left(HBox(EditBlkDeviceButton.new(device: @md)))
            )
        end
      end
    end
  end
end
