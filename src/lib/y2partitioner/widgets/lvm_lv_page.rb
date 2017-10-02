require "cwm/pager"

require "y2partitioner/icons"
require "y2partitioner/widgets/lvm_lv_description"
require "y2partitioner/widgets/edit_blk_device_button"

module Y2Partitioner
  module Widgets
    # A Page for a partition
    class LvmLvPage < CWM::Page
      # @param lvm_lv [Y2Storage::LvmLv]
      def initialize(lvm_lv)
        textdomain "storage"

        @lvm_lv = lvm_lv
        self.widget_id = "lvm_lv:" + lvm_lv.name
      end

      # @macro seeAbstractWidget
      def label
        @lvm_lv.lv_name
      end

      # @macro seeCustomWidget
      def contents
        return @contents if @contents

        icon = Icons.small_icon(Icons::LVM_LV)
        @contents = VBox(
          Left(
            HBox(
              Image(icon, ""),
              # TRANSLATORS: Heading. String followed by name of partition
              Heading(format(_("Logical Volume: %s"), @lvm_lv.name))
            )
          ),
          LvmLvDescription.new(@lvm_lv),
          Left(HBox(EditBlkDeviceButton.new(device: @lvm_lv)))
        )
      end
    end
  end
end
