require "y2storage"
require "yast"
require "cwm/dialog"
require "cwm/common_widgets"
require "cwm/custom_widget"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Determine the role of the new partition to be created which will allow to
    # propose some default format and mount options for it.
    # Part of {Sequences::AddPartition}.
    # Formerly MiniWorkflowStepRole
    class PartitionRole < CWM::Dialog
      # @param disk_name [String]
      # @param options [Y2Partitioner::FormatMount::Options]
      def initialize(disk_name, options)
        textdomain "storage"

        @disk_name = disk_name
        @options = options
      end

      # @macro seeDialog
      def title
        # dialog title
        Yast::Builtins.sformat(_("Add Partition on %1"), @disk_name)
      end

      # @macro seeDialog
      def contents
        HVSquash(RoleChoice.new(@options))
      end

      # Choose the role of the new partition
      class RoleChoice < CWM::RadioButtons
        # @param options [Y2Partitioner::FormatMount::Options]
        def initialize(options)
          textdomain "storage"

          @options = options
        end

        # @macro seeAbstractWidget
        def label
          _("Role")
        end

        # @macro seeAbstractWidget
        def help
          _("<p>Choose the role of the device.</p>")
        end

        def items
          [
            [:system, _("Operating System")],
            [:data, _("Data and ISV Applications")],
            [:swap, _("Swap")],
            [:efi_boot, _("EFI Boot Partition")],
            [:raw, _("Raw Volume (unformatted)")]
          ]
        end

        # @macro seeAbstractWidget
        def init
          self.value = @options.role || :data
        end

        # @macro seeAbstractWidget
        def store
          @options.options_for_role(value) if @options.role != value
        end
      end
    end
  end
end
