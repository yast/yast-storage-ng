require "yast"
require "cwm"
require "y2partitioner/sequences/add_lvm_lv"

module Y2Partitioner
  module Widgets
    # Button for opening the workflow to add a logical volume to a volume group.
    class AddLvmLvButton < CWM::PushButton
      # Constructor
      # @param vg [Y2Storage::LvmVg]
      def initialize(vg)
        textdomain "storage"
        @vg = vg
      end

      # @macro seeAbstractWidget
      def label
        _("Add...")
      end

      # @macro seeAbstractWidget
      def handle
        Sequences::AddLvmLv.new(@vg).run
        :redraw
      end
    end
  end
end
