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
require "cwm"
require "y2partitioner/widgets/menus/system"
require "y2partitioner/widgets/menus/view"
require "y2partitioner/widgets/menus/configure"

module Y2Partitioner
  module Widgets
    # Main menu bar of the partitioner
    class MainMenuBar < CWM::CustomWidget
      Yast.import "UI"
      include Yast::Logger

      # Constructor
      def initialize
        textdomain "storage"
        self.handle_all_events = true
        @menus = [
          Menus::System.new,
          Menus::View.new,
          Menus::Configure.new
        ]
        super
      end

      # Called by CWM after the widgets are created
      def init
        enable_items
      end

      def id
        :menu_bar
      end

      # Widget contents
      def contents
        @contents ||= MenuBar(Id(id), main_menus)
      end

      # Event handler for the main menu.
      #
      # @param event [Hash] UI event
      #
      def handle(event)
        return nil unless menu_event?(event)

        id = event["ID"]
        result = nil
        @menus.find do |menu|
          result = menu.handle(id)
        end
        result
      end

      private

      # Check if a UI event is a menu event
      def menu_event?(event)
        event["EventType"] == "MenuEvent"
      end

      #----------------------------------------------------------------------
      # Menu Definitions
      #----------------------------------------------------------------------

      def main_menus
        @menus.map do |menu|
          Menu(menu.label, menu.items)
        end
      end

      # Enable or disable menu items according to the current status
      def enable_items
        enable_edit_items
        enable_options_items
      end

      def enable_edit_items
        # Disable all items in the "Edit" menu for now: Right now they are only
        # there to demonstrate what the final menu will look like.
        disable_menu_items(:add, :edit, :delete, :delete_all, :resize, :move)
      end

      def enable_options_items
        # Not yet implemented on the menu level (:import_mount_points is!)
        disable_menu_items(:create_partition_table, :clone_partitions)
      end

      # Disable all items with the specified IDs
      def disable_menu_items(*ids)
        disabled_hash = ids.each_with_object({}) { |id, h| h[id] = false }
        Yast::UI.ChangeWidget(Id(id), :EnabledItems, disabled_hash)
      end
    end
  end
end
