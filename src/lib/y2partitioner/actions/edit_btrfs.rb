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
require "y2partitioner/actions/base"
require "y2partitioner/dialogs/btrfs_subvolumes"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Actions
    # Action for editing a BTRFS filesystem, see {Actions::Base}
    class EditBtrfs < Base
      # Constructor
      #
      # @param filesystem [Y2Storage::Filesystems::Btrfs]
      def initialize(filesystem)
        super()
        textdomain "storage"

        @filesystem = filesystem
        UIState.instance.select_row(filesystem)
      end

    private

      # @return [Y2Storage::Filesystems::Btrfs]
      attr_reader :filesystem

      # Opens a dialog to edit a BTRFS filesystem
      #
      # @see Actions::Base#perform_action
      def perform_action
        dialog = Dialogs::BtrfsSubvolumes.new(filesystem)

        dialog.run
      end

      # Result of the action
      #
      # @see Actions::Base#result
      #
      # It returns `:finish` when the action is performed. Otherwise, it returns
      # the result of the dialog, see {#perform_action}.
      #
      # @param action_result [Symbol] result of {#perform_action}
      # @return [Symbol]
      def result(action_result)
        return super if action_result == :ok

        action_result
      end
    end
  end
end
