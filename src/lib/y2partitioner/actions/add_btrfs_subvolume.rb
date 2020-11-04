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

require "y2partitioner/actions/base"
require "y2partitioner/actions/controllers/btrfs_subvolume"
require "y2partitioner/dialogs/btrfs_subvolume"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Actions
    # Action for adding a Btrfs subvolume, see {Actions::Base}
    class AddBtrfsSubvolume < Base
      # Constructor
      #
      # @param filesystem [Y2Storage::Filesystems::Btrfs]
      def initialize(filesystem)
        super()

        @controller = Controllers::BtrfsSubvolume.new(filesystem)
      end

      private

      # @return [Controllers::BtrfsSubvolume]
      attr_reader :controller

      # Opens a dialog to create a Btrfs subvolume
      #
      # The Btrfs subvolume is created only if the dialog is accepted.
      #
      # @see Actions::Base#perform_action
      def perform_action
        dialog = Dialogs::BtrfsSubvolume.new(controller)

        return unless dialog.run == :next

        controller.create_subvolume(controller.subvolume_path, controller.subvolume_nocow)
        UIState.instance.select_row(controller.subvolume.sid)

        :finish
      end
    end
  end
end
