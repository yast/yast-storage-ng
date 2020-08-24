# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/actions/configure_actions"

module Y2Partitioner
  module Widgets
    # "Configure" menu button used to run the corresponding YaST clients to
    # activate several storage technologies
    #
    # Most of the behavior of this widget is a direct translation of the old
    # Yast::PartitioningEpAllInclude from yast-storage
    class Configure < CWM::CustomWidget
      # Constructor
      def initialize
        textdomain "storage"
        @configure_actions = Actions::ConfigureActions.new
        super
      end

      # Content of the widget, a menu button with the list of available
      # configuration clients or an empty widget if no client is available
      #
      # @macro seeCustomWidget
      #
      # @return [Yast::WidgetTerm]
      def contents
        @contents ||= @configure_actions.empty? ? Empty() : MenuButton(Opt(*opt), label, items)
      end

      # Event handler for the configuration menu
      #
      # @param event [Hash] UI event
      # @return [:redraw, nil] :redraw when some configuration client was
      #   executed; nil otherwise.
      def handle(event)
        @configure_actions.run(event["ID"])
      end

      # @macro seeAbstractWidget
      def help
        # TRANSLATORS: help text for the Partitioner
        _(
          "<p>The <b>Configure</b> button offers several options to activate devices " \
          "that were not detected by the initial system analysis. After activating the " \
          "devices of the choosen technology, the system will be rescanned and all the " \
          "information about storage devices will be refreshed. " \
          "Thus, the <b>Provide Crypt Passwords</b> option is also useful when no " \
          "encryption is involved, to activate devices of other technologies like LVM " \
          "or Multipath.</p>"
        )
      end

      private

      # @return [Array<Yast::WidgetTerm>]
      def items
        @configure_actions.menu_items
      end

      # @return [Array<Symbol>]
      def opt
        [:key_F7]
      end

      # Localized label for the menu button
      #
      # @return [String]
      def label
        # Translators: Configure menu in the initial Partitioner screen
        _("Configure...")
      end

      # @macro seeCustomWidget
      #
      # Redefined in this class because the base implementation at CWM::CustomWidget
      # does not search for ids in the items of a MenuButton.
      def ids_in_contents
        @configure_actions.ids
      end
    end
  end
end
