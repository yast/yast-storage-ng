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

require "y2partitioner/widgets/tabs"
require "y2partitioner/widgets/pages/base"
require "abstract_method"

module Y2Partitioner
  module Widgets
    module Pages
      # Base class for pages containing several tabs, typically used to
      # represent a given device
      class Tabbed < Base
        # @see Base
        #
        # @return [Hash]
        def state_info
          tabs.current_page.state_info
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          @tabs = Tabs.new(*calculate_tabs)
          @contents =
            Top(
              VBox(
                Left(
                  tabs
                )
              )
            )
        end

        def init
          # Invalidate the memoized content so it gets recalculated in the next UI draw
          @contents = nil
        end

        private

        # Set of tabs of the page
        #
        # @return [Tabs]
        attr_reader :tabs

        # @see #tabs
        #
        # @return [Array<CWM::Tab>] All tabs must be able to respond to #state_info
        abstract_method :calculate_tabs
      end
    end
  end
end
