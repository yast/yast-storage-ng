require "yast"
require "y2partitioner/sequences/transaction_wizard"
require "y2partitioner/sequences/new_blk_device"
require "y2partitioner/sequences/controllers"
require "y2partitioner/dialogs/md"
require "y2partitioner/dialogs/md_options"

module Y2Partitioner
  module Sequences
    # formerly EpCreateRaid
    class AddMd < TransactionWizard
      include NewBlkDevice

      def preconditions
        return :next unless md_controller.available_devices.size < 2

        Yast::Popup.Error(
          _("There are not enough suitable unused devices to create a RAID.")
        )
        :back
      end

      skip_stack :preconditions

      def devices
        result = Dialogs::Md.run(md_controller)
        md_controller.apply_default_options if result == :next
        result
      end

      def md_options
        result = Dialogs::MdOptions.run(md_controller)
        if result == :next
          self.fs_controller = Controllers::Filesystem.new(md_controller.md, md_controller.wizard_title)
        end
        result
      end

    protected

      attr_reader :md_controller

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"      => "preconditions",
          "preconditions" => { next: "devices" },
          "devices"       => { next: "md_options" },
          "md_options"    => { next: new_blk_device_step1 }
        }.merge(new_blk_device_steps)
      end

      # @see TransactionWizard
      def init_transaction
        # The controller object must be created within the transaction
        @md_controller = Controllers::Md.new
      end
    end
  end
end
