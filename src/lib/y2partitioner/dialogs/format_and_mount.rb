require "yast"
require "y2partitioner/widgets/format_and_mount"

module Y2Partitioner
  module Dialogs
    # Which filesystem (and options) to use and where to mount it (with options).
    # Part of {Sequences::AddPartition} and {Sequences::EditBlkDevice}.
    # Formerly MiniWorkflowStepFormatMount
    class FormatAndMount < CWM::Dialog
      # @param options [Y2Partitioner::FormatMount::Options]
      def initialize(options)
        textdomain "storage"

        @options = options
      end

      def title
        "Edit Partition #{@options.name}"
      end

      def contents
        HVSquash(
          HBox(
            Widgets::FormatOptions.new(@options),
            HSpacing(5),
            Widgets::MountOptions.new(@options)
          )
        )
      end

      def cwm_show
        ret = nil

        loop do
          ret = super

          case ret
          when :redraw_partition_id
            redraw_partition_id
          when :redraw_filesystem
            redraw_filesystem
          else
            break
          end
        end

        ret
      end

      def redraw_partition_id
        @options.options_for_partition_id(@options.partition_id)
      end

      def redraw_filesystem
        @options.update_filesystem_options!
      end
    end
  end
end
