require "yast"
require "y2partitioner/sequences/transaction_wizard"
require "y2partitioner/sequences/new_blk_device"
require "y2partitioner/sequences/controllers"
require "y2partitioner/dialogs"

module Y2Partitioner
  module Sequences
    # Wizard to add a new LVM logical volume
    class AddLvmLv < TransactionWizard
      include NewBlkDevice

      # @param vg [Y2Storage::LvmVg]
      def initialize(vg)
        super()

        @controller = Controllers::LvmLv.new(vg)
      end

      def preconditions
        return :next if controller.free_extents > 0

        Yast::Popup.Error(
          # TRANSLATORS: %s is a volume group name (e.g. "system")
          _("No free space left in the volume group \"%s\".") % vg_name
        )
        :back
      end
      skip_stack :preconditions

      def name_and_type
        Dialogs::LvmLvInfo.run(controller)
      end

      def size
        controller.delete_lv
        result = Dialogs::LvmLvSize.run(controller)
        if result == :next
          controller.create_lv
          title = controller.wizard_title
          self.fs_controller = Controllers::Filesystem.new(controller.lv, title)
        end
        result
      end

    protected

      attr_reader :controller

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"      => "preconditions",
          "preconditions" => { next: "name_and_type" },
          "name_and_type" => { next: "size" },
          "size"          => { next: new_blk_device_step1, finish: :finish }
        }.merge(new_blk_device_steps)
      end

      # Name of the volume group
      #
      # @return [String]
      def vg_name
        controller.vg_name
      end
    end
  end
end
