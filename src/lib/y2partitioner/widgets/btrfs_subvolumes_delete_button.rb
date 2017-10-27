# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
require "y2partitioner/widgets/btrfs_subvolumes_table"
require "y2partitioner/device_graphs"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Widget to delete a btrfs subvolume from a table
    # @see Widgets::BtrfsSubvolumesTable
    class BtrfsSubvolumesDeleteButton < CWM::PushButton
      attr_reader :table

      # @param table [Widgets::BtrfsSubvolumesTable]
      def initialize(table)
        textdomain "storage"
        @table = table
      end

      # Widget label
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to delete a btrfs subvolume
        _("Delete...")
      end

      # Deletes a subvolume
      #
      # A confirmation popup is showed before deleting the subvolume.
      # An error message is presented when there is no selected table row.
      def handle
        subvolume = table.selected_subvolume

        if subvolume.nil?
          Yast::Popup.Error(_("Nothing selected"))
        else
          result = Yast::Popup.YesNo(
            # TRANSLATORS: %s is the path of the subvolume to be deleted
            format(_("Really delete subvolume %s?"), subvolume.path)
          )

          if result
            delete_subvolume(subvolume)
            table.refresh
          end
        end

        nil
      end

    private

      def delete_subvolume(subvolume)
        device_graph = DeviceGraphs.instance.current
        filesystem.delete_btrfs_subvolume(device_graph, subvolume.path)
      end

      def filesystem
        table.filesystem
      end
    end
  end
end
