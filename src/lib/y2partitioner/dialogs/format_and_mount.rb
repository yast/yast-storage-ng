require "yast"
require "y2partitioner/widgets/format_and_mount"

module Y2Partitioner
  module Dialogs
    # Which filesystem (and options) to use and where to mount it (with options).
    # Part of {Sequences::AddPartition} and {Sequences::EditBlkDevice}.
    # Formerly MiniWorkflowStepFormatMount
    class FormatAndMount < CWM::Dialog
      # @param controller [Sequences::FilesystemController]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
        @mount_options = Widgets::MountOptions.new(controller)
        @format_options = Widgets::FormatOptions.new(controller, @mount_options)
      end

      def title
        "Edit Partition #{@controller.blk_device.name}"
      end

      def contents
        HVSquash(
          HBox(
            @format_options,
            HSpacing(5),
            @mount_options
          )
        )
      end
    end
  end
end
