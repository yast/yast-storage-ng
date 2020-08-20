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

module Y2Partitioner
  module Widgets
    # Main menu bar of the partitioner
    class MainMenuBar < CWM::CustomWidget
      include Yast::Logger

      # Constructor
      def initialize
        textdomain "storage"
        self.handle_all_events = true
        super
      end

      # Widget contents
      def contents
        @contents ||= MenuBar(Id(:menu_bar), main_menus)
      end

      # Event handler for the main menu
      #
      # @param event [Hash] UI event
      # @return [:redraw, nil] :redraw when some configuration client was
      #   executed; nil otherwise.
      def handle(event)
        return nil unless menu_event?(event)
        id = event["ID"]
        log.info("Handling menu event: #{id}")
        nil
      end

      # Check if a UI event is a menu event
      def menu_event?(event)
        event["EventType"] == "MenuEvent"
      end

      private

      def main_menus
        textdomain "storage"
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
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id("Y2Partitioner::Widgets::RescanDevicesButton"), _("R&escan Devices")),
          Item(Id(_("Settings")), _("Se&ttings...")),
          Item("---"),
          Item(Id(:abort), _("&Abort (Abandoning Changes)")),
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
          Item(Id(:move), _("&Move...")),
        ].freeze
      end

      def view_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(_("Device Graphs")), _("Device &Graphs...")),
          Item(Id(_("Installation Summary")), _("Installation &Summary..."))
        ].freeze
      end

      def configure_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:CryptAction), _("Provide &Crypt Passwords...")),
          Item(Id(:IscsiAction), _("Configure &iSCSI...")),
          Item(Id(:FcoeAction), _("Configure &FCoE..."))
        ].freeze
      end

      def options_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:create_partition_table), _("Create New Partition &Table...")),
          Item(Id(:clone_partitions), _("&Clone Partitions to Other Devices..."))
        ].freeze
      end
    end
  end
end
