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
require "abstract_method"
require "y2partitioner/execute_and_redraw"

module Y2Partitioner
  module Widgets
    # Namespace to group all the menus in the main menu bar
    module Menus
      # Base class to represent a menu of the main menu bar
      class Base
        include Yast::I18n
        include Yast::UIShortcuts
        include ExecuteAndRedraw

        # @!method label
        #   @return [String] localized label for the menu
        abstract_method :label

        # @!method items
        #   @return [Array<Yast::Term>] menu entries
        abstract_method :items

        # @return [Array<Symbol>] ids of the menu items that should be disabled
        def disabled_items
          []
        end

        # @see MainMenuBar#handle
        #
        # @param event [Symbol]
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

        # Return a list of the IDs of all items in this menu.
        #
        # @return [Array<Symbol>] ids of the menu items
        def all_item_ids
          items.map { |item| item_id(item) }.compact
        end

        private

        # Dialog that should be opened for the given UI event
        #
        # @param _event [Symbol]
        # @return [Dialog::Base, nil] nil if the event does not correspond to any dialog
        def dialog_for(_event)
          nil
        end

        # Action that should be executed for the given UI event
        #
        # @param _event [Symbol]
        # @return [Actions::Base, nil] nil if the event does not correspond to any action
        def action_for(_event)
          nil
        end

        # Return the ID of a menu item.
        #
        # @return Symbol|String|nil
        def item_id(item)
          return nil if item.nil? || !item.is_a?(Yast::Term)

          id_term = item.first
          return nil if id_term.nil? || !id_term.is_a?(Yast::Term)
          return nil unless id_term.value == :id

          id_term.first
        end
      end
    end
  end
end
