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
require "y2partitioner/dialogs/summary_popup"
require "y2partitioner/dialogs/device_graph"

module Y2Partitioner
  module Widgets
    module Menus
      class View
        include Yast::I18n
        include Yast::UIShortcuts

        def label
          _("&View")
        end

        def items
          items = []
          # TRANSLATORS: Menu items in the partitioner
          items << Item(Id(:device_graphs), _("Device &Graphs...")) if Dialogs::DeviceGraph.supported?
          items << Item(Id(:installation_summary), _("Installation &Summary..."))
          items
        end

        def handle(event)
          dialog_for(event)&.run
          nil
        end

        private

        def dialog_for(event)
          case event
          when :device_graphs
            Dialogs::DeviceGraph.new
          when :installation_summary
            Dialogs::SummaryPopup.new
          end
        end
      end
    end
  end
end
