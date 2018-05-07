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
require "y2partitioner/dialogs"
require "y2partitioner/widgets/configurable_blk_devices_table"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Widget to edit a Btrfs filesystem
    class BtrfsEditButton < CWM::PushButton
      attr_reader :table

      # @param table [Widgets::ConfigurableBlkDevicesTable]
      def initialize(table)
        textdomain "storage"
        @table = table
      end

      # @see CWM::PushButton#Label
      def label
        _("Edit...")
      end

      # Opens a dialog to manage the list of subvolumes of the selected device
      #
      # @note In case of there is no selected table row, it shows an error.
      def handle
        filesystem = selected_filesystem

        if filesystem.nil?
          Yast::Popup.Error(_("There is no filesystem selected to edit."))
        else
          Dialogs::BtrfsSubvolumes.new(filesystem).run
        end

        nil
      end

    private

      # Filesystem of the currently selected device
      #
      # @return [Y2Storage::Filesystems::BlkFilesystem, nil]
      def selected_filesystem
        device = table.selected_device
        device.nil? ? nil : device.filesystem
      end
    end
  end
end
