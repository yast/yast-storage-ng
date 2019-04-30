# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/actions/transaction_wizard"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/dialogs/btrfs_options"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Actions
    # Action for editing a BTRFS filesystem, see {Actions::Base}
    class EditBtrfs < TransactionWizard
      # Constructor
      #
      # @param filesystem [Y2Storage::Filesystems::Btrfs]
      def initialize(filesystem)
        super()

        textdomain "storage"

        @device_sid = filesystem.sid
        UIState.instance.select_row(filesystem)
      end

    private

      # @return [Controllers::Filesystem]
      attr_reader :controller

      # Wizard step title
      #
      # @return [String]
      def title
        # TRANSLATORS: Wizard step title, where %{basename} is replaced by the device
        # base name (e.g., sda1).
        format(_("Edit Btrfs %{basename}"), basename: device.blk_device_basename)
      end

      def init_transaction
        @controller = Controllers::Filesystem.new(device, title)
      end

      def sequence_hash
        {
          "ws_start"      => "btrfs_options",
          "btrfs_options" => { next: :finish }
        }
      end

      # Opens a dialog to edit a BTRFS filesystem
      def btrfs_options
        dialog = Dialogs::BtrfsOptions.new(controller)
        dialog.run
      end
    end
  end
end
