require "y2storage"
require "yast"
require "y2partitioner/filesystem_role"
require "cwm/dialog"
require "cwm/common_widgets"
require "cwm/custom_widget"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Determine the role of the new partition or LVM logical volume to be
    # created which will allow to propose some default format and mount options
    # for it.
    # Part of {Actions::AddPartition}.
    # Formerly MiniWorkflowStepRole
    class PartitionRole < CWM::Dialog
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(RoleChoice.new(controller))
      end

    private

      attr_reader :controller

      # Choose the role of the new partition
      class RoleChoice < CWM::RadioButtons
        # @param controller [Actions::Controllers::Filesystem]
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
          FilesystemRole.all.map { |role| [role.id, role.name] }
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.role_id || :data
        end

        # @macro seeAbstractWidget
        def store
          @controller.role_id = value
        end
      end
    end
  end
end
