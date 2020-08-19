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

module Y2Partitioner
  module Dialogs
    module MainMenus
      def main_menus
        textdomain "storage"
        [
          # TRANSLATORS: Pulldown menus in the partitioner
          Menu(_("&System"), system_menu),
          Menu(_("&Edit"), edit_menu),
          Menu(_("&View"), view_menu),
          Menu(_("&Options"), options_menu)
        ].freeze
      end

      def system_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:rescan_devices), _("R&escan Devices")),
          Item(Id(:settings), _("Se&ttings...")),
          Item("---"),
          Item(Id(:abort), _("&Abort (Without Saving)")),
          Item("---"),
          Item(Id(:finish), _("&Finish (Save and Exit)"))
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
          Item(Id(:view_device_graphs), _("Device &Graphs...")),
          Item(Id(:view_summary), _("Installation &Summary..."))
        ].freeze
      end

      def options_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:crypt_passwords), _("Provide &Crypt Passwords...")),
          Menu(_("Partition &Table"), partition_table_menu),
          Menu(_("&Network Storage"), network_storage_menu)
        ].freeze
      end

      def partition_table_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:create_partition_table), _("Create New Partition &Table...")),
          Item(Id(:clone_partitions), _("&Clone Partitions to Other Devices..."))
        ].freeze
      end

      def network_storage_menu
        [
          # TRANSLATORS: Menu items in the partitioner
          Item(Id(:configure_iscsi), _("Configure &iSCSI...")),
          Item(Id(:configure_fcoe), _("Configure &FCoE..."))
        ].freeze
      end
    end
  end
end
