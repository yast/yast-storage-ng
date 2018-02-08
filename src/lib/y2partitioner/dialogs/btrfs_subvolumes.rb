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
require "y2partitioner/widgets/btrfs_subvolumes"
require "y2partitioner/dialogs/popup"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Dialogs
    # Popup dialog to configure subvolumes and options for a btrfs filesystem
    class BtrfsSubvolumes < Popup
      # @param filesystem [Y2Storage::Filesystems::BlkFilesystem] a btrfs filesystem
      def initialize(filesystem)
        textdomain "storage"

        @fs_sid = filesystem.sid
      end

      def title
        _("Edit Btrfs subvolumes")
      end

      # All contents are defined by a btrfs subvolumes widget
      # @see Widgets::BtrfsSubvolumes
      def contents
        VBox(Widgets::BtrfsSubvolumes.new(filesystem))
      end

      # Executes changes in a transaction
      #
      # Devicegraph changes are only stored if the dialog is accepted
      # @see DeviceGraphs#transaction
      def run
        result = nil
        DeviceGraphs.instance.transaction do
          result = super
          result == :ok
        end
        result
      end

      # The dialog runs a transaction, so it is necessary to ensure that
      # the filesystem belonging to the current devicegraph is used
      def filesystem
        DeviceGraphs.instance.current.find_device(@fs_sid)
      end
    end
  end
end
