require "yast"
require "y2partitioner/actions/transaction_wizard"
require "y2partitioner/actions/controllers/lvm_vg"
require "y2partitioner/dialogs/lvm_vg"

module Y2Partitioner
  module Actions
    # Action for creating a new LVM volume group
    class AddLvmVg < TransactionWizard
      # Runs the dialog for creating the volume group and applies
      # the given values to new created volume group.
      #
      # @see Controllers::LvmVg#apply_values
      #
      # @return [Symbol] :finish when the dialog successes
      def add_vg
        result = Dialogs::LvmVg.run(controller)
        return result if result != :next

        controller.apply_values
        :finish
      end

    protected

      # @return [Controllers::LvmVg]
      attr_reader :controller

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start" => "add_vg",
          "add_vg"   => { finish: :finish }
        }
      end

      # @see TransactionWizard
      # @note The controller object must be created within the transaction because
      #   a new volume group is created during initialization
      def init_transaction
        @controller = Controllers::LvmVg.new
      end

      # @see TransactionWizard
      # @note The action is only run when there are available devices to create a new
      #   volume group (see {Controllers::LvmVg#available_devices}).
      #
      # @return [Boolean] true whether there are available devices; false otherwise.
      def run?
        return true if controller.available_devices.size > 0

        Yast::Popup.Error(
          _("There are not enough suitable unused devices to create a volume group.\n") + "\n" +
          _("To use LVM, at least one unused partition of type 0x8e (or 0x83) or one disk\n" \
            "or one RAID device is required. Change your partition table accordingly.")
        )

        false
      end
    end
  end
end
