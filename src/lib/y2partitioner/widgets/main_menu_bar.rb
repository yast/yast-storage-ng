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
require "y2partitioner/execute_and_redraw"
require "y2partitioner/actions/rescan_devices"
require "y2partitioner/actions/configure_actions"
require "y2partitioner/actions/import_mount_points"
require "y2partitioner/dialogs/summary_popup"
require "y2partitioner/dialogs/settings"
require "y2partitioner/dialogs/device_graph"

module Y2Partitioner
  module Widgets
    # Main menu bar of the partitioner
    class MainMenuBar < CWM::CustomWidget
      Yast.import "UI"
      Yast.import "Stage"
      include Yast::Logger
      include ExecuteAndRedraw

      # Constructor
      def initialize
        textdomain "storage"
        self.handle_all_events = true
        @configure_actions = Actions::ConfigureActions.new
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
        if @configure_actions.contain?(id)
          @configure_actions.run(id)
        else
          call_menu_item_handler(id)
        end
      end

      private

      # Check if a UI event is a menu event
      def menu_event?(event)
        event["EventType"] == "MenuEvent"
      end

      # Call a method "handle_id" for a menu item with ID "id" if such a method
      # is defined in this class.
      def call_menu_item_handler(id)
        return nil if id.nil?

        # log.info("Handling menu event: #{id}")
        handler = "handle_#{id}"
        if respond_to?(handler, true)
          log.info("Calling #{handler}()")
          send(handler)
        else
          log.info("No method #{handler}")
          nil
        end
      end

      # Check if we are running in the initial stage of an installation
      def installation?
        Yast::Stage.initial
      end

      #----------------------------------------------------------------------
      # Menu Definitions
      #----------------------------------------------------------------------

      def main_menus
        [
          # TRANSLATORS: Pulldown menus in the partitioner
          Menu(_("&System"), system_menu),
          Menu(_("&Edit"), edit_menu),
          Menu(_("&View"), view_menu),
          Menu(_("&Configure"), configure_menu),
          Menu(_("&Options"), options_menu)
        ].freeze
      end

      def system_menu
        # For each item with an ID "xy", write a "handle_xy" method.
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:rescan_devices), _("R&escan Devices")),
          Item(Id(:settings), _("Se&ttings...")),
          Item("---"),
          Item(Id(:abort), _("Abo&rt (Abandon Changes)")),
          Item("---"),
          Item(Id(:next), _("&Finish (Save and Exit)"))
        ].freeze
      end

      def edit_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:add), _("&Add...")),
          Item(Id(:edit), _("&Edit...")),
          Item(Id(:delete), _("&Delete")),
          Item(Id(:delete_all), _("Delete A&ll")),
          Item("---"),
          Item(Id(:resize), _("Resi&ze...")),
          Item(Id(:move), _("&Move..."))
        ].freeze
      end

      def view_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:device_graphs), _("Device &Graphs...")),
          Item(Id(:installation_summary), _("Installation &Summary..."))
        ].freeze
      end

      def configure_menu
        @configure_actions.menu_items
      end

      def options_menu
        items = []
        # TRANSLATORS: Menu items in the partitioner
        items << Item(Id(:create_partition_table), _("Create New Partition &Table..."))
        items << Item(Id(:clone_partitions), _("&Clone Partitions to Other Devices..."))
        items << Item(Id(:import_mount_points), _("&Import Mount Points...")) if installation?
        items
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

      # Disable a all items with the specified IDs
      def disable_menu_items(*ids)
        disabled_hash = ids.each_with_object({}) { |id, h| h[id] = false }
        Yast::UI.ChangeWidget(Id(id), :EnabledItems, disabled_hash)
      end

      #----------------------------------------------------------------------
      # Handlers for the menu actions
      #
      # For each menu item with ID xy, write a method handle_xy.
      # The methods are found via introspection in the event handler.
      #----------------------------------------------------------------------

      def handle_rescan_devices
        execute_and_redraw { Actions::RescanDevices.new.run }
      end

      def handle_settings
        Dialogs::Settings.new.run
        nil
      end

      def handle_abort
        # This is handled by the CWM base classes as the "Abort" wizard button.
        nil
      end

      def handle_next
        # This is handled by the CWM base classes as the "Next" wizard button.
        nil
      end

      def handle_device_graphs
        Dialogs::DeviceGraph.new.run
        nil
      end

      def handle_installation_summary
        Dialogs::SummaryPopup.run
        nil
      end

      def handle_import_mount_points
        execute_and_redraw { Actions::ImportMountPoints.new.run }
      end
    end
  end
end
