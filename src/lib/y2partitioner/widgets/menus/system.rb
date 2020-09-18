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
require "y2partitioner/widgets/menus/configure"
require "y2partitioner/actions/rescan_devices"
require "y2partitioner/actions/import_mount_points"

module Y2Partitioner
  module Widgets
    module Menus
      # Class representing the System menu
      class System < Base
        Yast.import "Stage"

        # @see Base
        def initialize(*args)
          textdomain "storage"
          super
        end

        # @see Base
        def label
          # TRANSLATORS: Partitioner menu with actions that affect the whole
          # system or the whole Partitioner itself
          _("&System")
        end

        # @see Base
        def items
          return @items if @items

          @items =
            if installation?
              [Item(Id(:import_mount_points), _("&Import Mount Points..."))]
            else
              []
            end

          @items += [
            Item(Id(:rescan_devices), _("&Rescan Devices")),
            Menu(_("&Configure"), configure_menu.items),
            Item("---"),
            Item(Id(:abort), _("&Abort (Abandon Changes)")),
            Item("---"),
            Item(Id(:next), _("&Finish (Save and Exit)"))
          ]
        end

        # @see Base
        def handle(event)
          configure_menu.handle(event) || super
        end

        private

        # Whether we are running in the initial stage of an installation
        #
        # @return [Boolean]
        def installation?
          Yast::Stage.initial
        end

        # Submenu with all the configure entries
        def configure_menu
          @configure_menu ||= Menus::Configure.new
        end

        # @see Base
        def action_for(event)
          if event == :rescan_devices
            Actions::RescanDevices.new
          elsif event == :import_mount_points
            Actions::ImportMountPoints.new
          end
        end
      end
    end
  end
end
