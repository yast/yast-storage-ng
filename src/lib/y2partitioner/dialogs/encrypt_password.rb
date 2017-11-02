require "yast"
require "cwm/dialog"
require "y2partitioner/widgets/encrypt_password"

module Y2Partitioner
  module Dialogs
    # Ask for a password to assign to an encrypted device.
    # Part of {Actions::AddPartition} and {Actions::EditBlkDevice}.
    # Formerly MiniWorkflowStepPassword
    class EncryptPassword < CWM::Dialog
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      def title
        _("Encryption password for %s") % @controller.blk_device_name
      end

      def contents
        HVSquash(
          Widgets::EncryptPassword.new(@controller)
        )
      end
    end
  end
end
