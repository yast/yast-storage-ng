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
require "y2partitioner/execute_and_redraw"
require "y2partitioner/dialogs/settings"
require "y2partitioner/actions/rescan_devices"
require "y2partitioner/actions/import_mount_points"

module Y2Partitioner
  module Widgets
    module Menus
      class System
        Yast.import "Stage"
        include Yast::I18n
        include Yast::UIShortcuts
        include ExecuteAndRedraw

        def label
          _("&System")         
        end

        def items
          items = [Item(Id(:rescan_devices), _("R&escan Devices"))]
          items << Item(Id(:import_mount_points), _("&Import Mount Points...")) if installation?
          items += [
            Item(Id(:settings), _("Se&ttings...")),
            Item("---"),
            Item(Id(:abort), _("Abo&rt (Abandon Changes)")),
            Item("---"),
            Item(Id(:next), _("&Finish (Save and Exit)"))
          ]
        end

        def handle(event)
          action = action_for(event)
          if action
            execute_and_redraw { action.run }
          else
            dialog = dialog_for(event)
            dialog&.run
            nil
          end
        end

        private

        # Check if we are running in the initial stage of an installation
        def installation?
          Yast::Stage.initial
        end

        def action_for(event)
          if event == :rescan_devices
            Actions::RescanDevices.new
          elsif event == :import_mount_points
            Actions::ImportMountPoints.new
          end
        end

        def dialog_for(event)
          if event == :settings
            Dialogs::Settings.new
          end
        end
      end
    end
  end
end
