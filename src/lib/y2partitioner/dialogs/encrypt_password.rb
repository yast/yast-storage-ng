require "yast"
require "cwm/dialog"
require "y2partitioner/widgets/encrypt_password"

module Y2Partitioner
  module Dialogs
    # Ask for a password to assign to an encrypted device.
    # Part of {Sequences::AddPartition} and {Sequences::EditBlkDevice}.
    # Formerly MiniWorkflowStepPassword
    class EncryptPassword < CWM::Dialog
      # @param options [Y2Partitioner::FormatMount::Options]
      def initialize(options)
        textdomain "storage"

        @options = options
      end

      def title
        _("Encryption password for %s") % @options.name
      end

      def contents
        HVSquash(
          Widgets::EncryptPassword.new(@options)
        )
      end
    end
  end
end
