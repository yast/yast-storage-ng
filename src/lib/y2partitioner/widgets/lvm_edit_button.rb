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
require "y2partitioner/actions/edit_blk_device"
require "y2partitioner/widgets/device_button"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Widgets
    # Button for editing a volume group or logical volume
    class LvmEditButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        _("Edit...")
      end

    protected

      # When a vg is edited, go directly to that vg entry in the tree view.
      # When a lv is edited, start the proper wizard.
      #
      # @see DeviceButton#actions
      def actions
        actions_result = case device
        when Y2Storage::LvmVg
          edit_vg
        when Y2Storage::LvmLv
          edit_lv
        end

        result(actions_result)
      end

      # If pager is known, jumps to the vg page
      def edit_vg
        return unless pager

        page = pager.device_page(device)
        UIState.instance.go_to_tree_node(page)
        :finish
      end

      # Opens workflow to edit the lv
      def edit_lv
        UIState.instance.select_row(device.sid)
        Actions::EditBlkDevice.new(device).run
      end
    end
  end
end
