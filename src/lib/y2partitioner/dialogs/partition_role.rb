require "y2storage"
require "yast"
require "cwm/dialog"
require "cwm/common_widgets"
require "cwm/custom_widget"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Determine the role of the new partition or LVM logical volume to be
    # created which will allow to propose some default format and mount options
    # for it.
    # Part of {Sequences::AddPartition}.
    # Formerly MiniWorkflowStepRole
    class PartitionRole < CWM::Dialog
      # @param controller [Sequences::FilesystemController]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      # @macro seeDialog
      def title
        # dialog title
        Yast::Builtins.sformat(_("Add Partition on %1"), disk_name)
      end

      # @macro seeDialog
      def contents
        HVSquash(RoleChoice.new(controller))
      end

    private

      attr_reader :controller

      def disk_name
        controller.blk_device.partitionable.name
      end

      # Choose the role of the new partition
      class RoleChoice < CWM::RadioButtons
        # @param controller [Sequences::Filesystemcontroller]
        def initialize(controller)
          textdomain "storage"

          @controller = controller
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
          self.value = @controller.role || :data
        end

        # @macro seeAbstractWidget
        def store
          @controller.role = value
        end
      end
    end
  end
end
