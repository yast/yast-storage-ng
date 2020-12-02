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
require "y2partitioner/ui_state"
require "y2partitioner/actions/transaction_wizard"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/dialogs/tmpfs"

module Y2Partitioner
  module Actions
    # Action for creating a new Tmpfs filesystem
    class EditTmpfs < TransactionWizard
      # Constructor
      #
      # @param filesystem [Y2Storage::Filesystems::Tmpfs]
      def initialize(filesystem)
        super()
        textdomain "storage"

        @device_sid = filesystem.sid
        UIState.instance.select_row(filesystem.sid)
      end

      # Only step of the wizard
      #
      # @see Dialogs::Tmpfs
      #
      # @return [Symbol] :finish when the dialog successes
      def edit_tmpfs
        result = Dialogs::Tmpfs.run(fs_controller, edit: true)
        return result if result != :next

        fs_controller.finish
        :finish
      end

      protected

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"   => "edit_tmpfs",
          "edit_tmpfs" => { finish: :finish }
        }
      end

      def fs_controller
        @fs_controller ||= Controllers::Filesystem.new(device, title)
      end

      # Wizard title
      #
      # @return [String]
      def title
        # TRANSLATORS: wizard title when editing a tmpfs filesystem, where %s is
        # replaced by the path where tmpfs is mounted
        format(_("Edit Tmpfs at %s"), device.mount_path)
      end
    end
  end
end
