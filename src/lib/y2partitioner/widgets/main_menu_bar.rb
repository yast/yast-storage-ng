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
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/menus/system"
require "y2partitioner/widgets/menus/add"
require "y2partitioner/widgets/menus/modify"
require "y2partitioner/widgets/menus/view"

module Y2Partitioner
  module Widgets
    # Main menu bar of the partitioner
    class MainMenuBar < CWM::CustomWidget
      include Yast::I18n
      Yast.import "UI"

      # @return [Array<Menus::Base>]
      attr_reader :menus

      # Constructor
      def initialize
        textdomain "storage"
        self.handle_all_events = true
        @device = nil
        @menus = []
        super
      end

      # @see UIState#select_row
      def select_row(id)
        @device = find_device(id)
        refresh
      end

      # @see UIState#select_page
      def select_page
        @device = nil
        refresh
      end

      # @macro seeAbstractWidget
      def id
        :menu_bar
      end

      # @macro seeAbstractWidget
      def contents
        @contents ||= MenuBar(Id(id), items)
      end

      # Event handler for the main menu.
      #
      # @param event [Hash] UI event
      # @return [Symbol, nil]
      def handle(event)
        return nil unless menu_event?(event)

        id = event["ID"]
        result = nil
        menus.find do |menu|
          result = menu.handle(id)
        end
        result
      end

      # @macro seeAbstractWidget
      # @return [String] localized help text
      def help
        _(
          # TRANSLATORS: html text containing the help for the Partitioner menubar, make
          # sure the titles match the menu names
          "<p>All the possible Partitioner actions are represented in the\n" \
          "menu bar at the top:</p>\n" \
          "<ul>\n" \
          "<li><b>System</b>\n" \
          "contains global actions that affect the storage setup as a whole.\n" \
          "</li>\n" \
          "<li><b>Add</b>\n" \
          "allows to create new virtual devices and also to divide the device\n" \
          "selected below into logical units like partitions or subvolumes.\n" \
          "</li>\n" \
          "<li><b>Device</b>\n" \
          "gathers all the actions that can be performed on the entry currently\n" \
          "selected in the table below.\n" \
          "</li>\n" \
          "<li><b>View</b>\n" \
          "grants access to special sections of the Partitioner not strictly related\n" \
          "to the current selected device.\n" \
          "</li>\n" \
          "</ul>"
        )
      end

      private

      # Device currently selected in the UI, if any
      #
      # @return [Y2Storage::Device, nil]
      attr_reader :device

      # Check if a UI event is a menu event
      def menu_event?(event)
        event["EventType"] == "MenuEvent"
      end

      # @return [Array<Yast::Term>]
      def items
        menus.map { |m| Menu(m.label, m.items) }
      end

      # @return [Array<Symbol>]
      def disabled_items
        menus.flat_map(&:disabled_items)
      end

      # Redraws the widget
      def refresh
        @menus = calculate_menus
        Yast::UI.ChangeWidget(Id(id), :Items, items)
        disable_menu_items(*disabled_items)
      end

      # Set of menus for the current {#device} and {#page_device}
      #
      # @return [Array<Menus::Base>]
      def calculate_menus
        [system_menu, add_menu, modify_menu, view_menu]
      end

      # Disable all items with the specified IDs
      def disable_menu_items(*ids)
        disabled_hash = ids.each_with_object({}) { |id, h| h[id] = false }
        Yast::UI.ChangeWidget(Id(id), :EnabledItems, disabled_hash)
      end

      # @see #calculate_menus
      def system_menu
        @system_menu ||= Menus::System.new
      end

      # @see #calculate_menus
      def view_menu
        @view_menu ||= Menus::View.new
      end

      # @see #calculate_menus
      def add_menu
        Menus::Add.new(device)
      end

      # @see #calculate_menus
      def modify_menu
        Menus::Modify.new(device)
      end

      # @return [Y2Storage::Devicegraph]
      def devicegraph
        DeviceGraphs.instance.current
      end

      # @param sid [Integer]
      # @return [Y2Storage::Device, nil]
      def find_device(sid)
        devicegraph.find_device(sid)
      end
    end
  end
end
