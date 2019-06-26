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
require "y2partitioner/widgets/device_menu_button"
require "y2partitioner/actions/edit_btrfs"
require "y2partitioner/actions/edit_btrfs_devices"

module Y2Partitioner
  module Widgets
    # Menu button for modifying a Btrfs filesystem
    class BtrfsModifyButton < DeviceMenuButton
      def initialize(*args)
        super
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        _("&Modify")
      end

      private

      # @see DeviceMenuButton#actions
      #
      # @see Actions::EditBtrfs
      # @see Actions::EditBtrfsDevices
      #
      # @return [Array<Hash>]
      def actions
        [
          {
            id:    :edit,
            label: _("Edit Btrfs..."),
            class: Actions::EditBtrfs
          },
          {
            id:    :devices,
            label: _("Change Used Devices..."),
            class: Actions::EditBtrfsDevices
          }
        ]
      end
    end
  end
end
