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

require "yast"
require "y2partitioner/widgets/menus/base"
require "y2partitioner/dialogs/summary_popup"
require "y2partitioner/dialogs/device_graph"
require "y2partitioner/dialogs/settings"
require "y2partitioner/dialogs/bcache_csets"

module Y2Partitioner
  module Widgets
    module Menus
      # Class to represent the View menu
      class View < Base
        # Constructor
        def initialize
          textdomain "storage"
        end

        # @see Base
        def label
          _("&View")
        end

        # @see Base
        def items
          return @items if @items

          @items =
            if Dialogs::DeviceGraph.supported?
              [Item(Id(:device_graphs), _("Device &Graphs..."))]
            else
              []
            end

          @items += [
            Item(Id(:installation_summary), _("Installation &Summary...")),
            Item(Id(:settings), _("Se&ttings...")),
            Item(Id(:bcache_csets), _("Bcache Caching Sets..."))
          ]
        end

        private

        # @see Base
        def dialog_for(event)
          case event
          when :device_graphs
            Dialogs::DeviceGraph.new
          when :installation_summary
            Dialogs::SummaryPopup.new
          when :settings
            Dialogs::Settings.new
          when :bcache_csets
            Dialogs::BcacheCsets.new
          end
        end
      end
    end
  end
end
