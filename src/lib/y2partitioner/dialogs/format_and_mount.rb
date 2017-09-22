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
        @format_and_mount = FormatMountOptions.new(controller)
      end

      def title
        "Edit Partition #{@controller.blk_device.name}"
      end

      def contents
        HVSquash(@format_and_mount)
      end

      # Simple container widget to allow the format options and the mount
      # options widgets to refresh each other.
      class FormatMountOptions < CWM::CustomWidget
        def initialize(controller)
          textdomain "storage"

          @controller = controller
          @format_options = Widgets::FormatOptions.new(controller, self)
          @mount_options = Widgets::MountOptions.new(controller, self)

          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def contents
          HBox(
            @format_options,
            HSpacing(5),
            @mount_options
          )
        end

        # Used by the children widgets to notify they have changed the status of
        # the controller and, thus, some of its sibling widgets may need a
        # refresh.
        #
        # @param exclude [CWM::AbstractWidget] widget originating the change,
        #   and thus not needing a forced refresh
        def refresh_others(exclude)
          if exclude == @format_options
            @mount_options.refresh
          else
            @format_options.refresh
          end
        end
      end
    end
  end
end
