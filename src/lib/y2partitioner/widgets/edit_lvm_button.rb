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
require "y2partitioner/sequences/edit_blk_device"
require "y2partitioner/widgets/blk_device_button"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Widgets
    # Button for editing a volume group or logical volume
    class EditLvmButton < BlkDeviceButton
      # @macro seeAbstractWidget
      def label
        _("Edit...")
      end

      # When a vg is edited, go directly to that vg entry in the tree view.
      # When a lv is edited, start the proper wizard.
      # @see BlkDeviceButton#actions
      def actions
        case device
        when Y2Storage::LvmVg
          page = pager.device_page(device)
          UIState.instance.go_to_tree_node(page)
        when Y2Storage::LvmLv
          UIState.instance.select_row(device.sid)
          Sequences::EditBlkDevice.new(device).run
        end

        :redraw
      end
    end
  end
end
