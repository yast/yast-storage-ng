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
require "y2partitioner/widgets/menus/go"
require "y2partitioner/widgets/menus/extra"

module Y2Partitioner
  module Widgets
    # Main menu bar of the partitioner
    class MainMenuBar < CWM::CustomWidget
      Yast.import "UI"

      # @return [Array<Menus::Base>]
      attr_reader :menus

      # Constructor
      def initialize
        self.handle_all_events = true
        @device = nil
        @page_device = nil
        @menus = []
        super
      end

      # @see UIState#select_row
      def select_row(id)
        @device = find_device(id)
        refresh
      end

      # @see UIState#select_page
      def select_page(pages_ids)
        dev_id = pages_ids.reverse.find { |id| id.is_a?(Integer) }
        @page_device = dev_id ? find_device(dev_id) : nil
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

      private

      # Device currently selected in the UI, if any
      #
      # @return [Y2Storage::Device, nil]
      attr_reader :device

      # Device currently selected in the left tree, if any
      #
      # @return [Y2Storage::Device, nil]
      attr_reader :page_device

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
        [
          Menus::System.new,
          Menus::Modify.new(device || page_device),
          Menus::Add.new(device || page_device),
          Menus::View.new,
          Menus::Go.new(page_device || device),
          Menus::Extra.new(page_device || device)
        ]
      end

      # Disable all items with the specified IDs
      def disable_menu_items(*ids)
        disabled_hash = ids.each_with_object({}) { |id, h| h[id] = false }
        Yast::UI.ChangeWidget(Id(id), :EnabledItems, disabled_hash)
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
