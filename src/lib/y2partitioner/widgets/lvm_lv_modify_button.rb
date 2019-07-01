# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/actions/edit_blk_device"
require "y2partitioner/actions/resize_blk_device"

module Y2Partitioner
  module Widgets
    # Menu button for modifying an LVM logical volume
    class LvmLvModifyButton < DeviceMenuButton
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
      def actions
        [
          { id: :edit,   label: _("Edit Logical Volume..."),   class: Actions::EditBlkDevice },
          { id: :resize, label: _("Resize Logical Volume..."), class: Actions::ResizeBlkDevice }
        ]
      end
    end
  end
end
