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

      # Wizard step to indicate properties for a new logical volume,
      # i.e., the name and type.
      #
      # @note Given values are stored into the controller.
      # @see Controllers::LvmLv
      # @see Dialogs::LvmLvInfo.run
      def name_and_type
        Dialogs::LvmLvInfo.run(controller)
      end

      # Wizard step to indicate the size and stripes data (number and size)
      # for the new logical volume.
      #
      # @note Given values are stored into the controller and then a new
      #   logical volume is created with those values. When a previous logical
      #   volume exists (e.g, when going back in the wizard), that volume is
      #   deleted before creating a new one.
      #
      # @see Controllers::LvmLv
      # @see Dialogs::LvmLvSize.run
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

      # @return [Controllers::LvmLv]
      attr_reader :controller

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"      => "name_and_type",
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

      # @see TransactionWizard
      def run?
        return true if controller.free_extents > 0

        Yast::Popup.Error(
          # TRANSLATORS: %s is a volume group name (e.g. "system")
          _("No free space left in the volume group \"%s\".") % vg_name
        )
        false
      end
    end
  end
end
