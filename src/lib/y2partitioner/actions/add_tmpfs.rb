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
    class AddTmpfs < TransactionWizard
      # Constructor
      def initialize
        super
        textdomain "storage"
      end

      # Only step of the wizard
      #
      # @see Dialogs::Tmpfs
      #
      # @return [Symbol] :finish when the dialog successes
      def add_tmpfs
        result = Dialogs::Tmpfs.run(fs_controller)
        return result if result != :next

        fs_controller.finish
        UIState.instance.select_row(tmpfs.sid)
        :finish
      end

      protected

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"  => "add_tmpfs",
          "add_tmpfs" => { finish: :finish }
        }
      end

      # The tmpfs object must be created within the transaction
      def tmpfs
        @tmpfs ||= Y2Storage::Filesystems::Tmpfs.create(DeviceGraphs.instance.current)
      end

      def fs_controller
        @fs_controller ||= Controllers::Filesystem.new(tmpfs, title)
      end

      # Wizard title
      #
      # @return [String]
      def title
        # TRANSLATORS: wizard title when creating a new Tmpfs filesystem.
        _("Add Tmpfs")
      end
    end
  end
end
