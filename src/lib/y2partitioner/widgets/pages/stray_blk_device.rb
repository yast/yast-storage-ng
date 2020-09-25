# Copyright (c) [2017-2019] SUSE LLC
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
require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/overview_tab"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a StrayBlkDevice (basically a XEN virtual partition)
      class StrayBlkDevice < Base
        # @return [Y2Storage::StrayBlkDevice] device the page is about
        attr_reader :device

        # Constructor
        #
        # @param [Y2Storage::StrayBlkDevice] device
        def initialize(device)
          textdomain "storage"

          @device = device
          self.widget_id = "stray_blk_device:" + device.name
        end

        # @macro seeAbstractWidget
        def label
          device.basename
        end

        # @macro seeCustomWidget
        def contents
          @contents ||=
            Top(
              VBox(
                Left(
                  OverviewTab.new(device, @pager)
                )
              )
            )
        end
      end
    end
  end
end
