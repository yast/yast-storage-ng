require "yast"
require "cwm"
require "y2partitioner/sequences/edit_blk_device"
require "y2partitioner/widgets/blk_device_button"
require "y2partitioner/ui_state"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Button for opening the editing workflow (basically mount and format
    # options) on a block device.
    class EditBlkDeviceButton < BlkDeviceButton
      def label
        _("Edit...")
      end

      # @see BlkDeviceButton#actions
      def actions
        UIState.instance.select_row(device.sid)
        Sequences::EditBlkDevice.new(device).run
        :redraw
      end
    end
  end
end
