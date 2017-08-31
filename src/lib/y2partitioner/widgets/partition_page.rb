require "cwm/pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/delete_disk_partition_button"
require "y2partitioner/widgets/partition_description"
require "y2partitioner/dialogs/format_and_mount"
require "y2partitioner/sequences/edit_blk_device"

module Y2Partitioner
  module Widgets
    # A Page for a partition
    class PartitionPage < CWM::Page
      # Constructor
      #
      # @param [Y2Storage::Partition] partition
      def initialize(partition)
        textdomain "storage"

        @partition = partition
        self.widget_id = "partition:" + partition.name
      end

      # @macro seeAbstractWidget
      def label
        @partition.basename
      end

      # @macro seeCustomWidget
      def contents
        # FIXME: this is called dozens of times per single click!!
        return @contents if @contents

        icon = Icons.small_icon(Icons::HD_PART)
        @contents = VBox(
          Left(
            HBox(
              Image(icon, ""),
              # TRANSLATORS: Heading. String followed by name of partition
              Heading(format(_("Partition: "), @partition.name))
            )
          ),
          PartitionDescription.new(@partition),
          EditButton.new(@partition),
          DeleteDiskPartitionButton.new(device: @partition)
        )
      end

      # Edit a partition
      # FIXME: this is NEARLY a duplicate of DiskPage::EditButton but that one works with a table.
      # Analogous to DeleteDiskPartitionButton??
      class EditButton < CWM::PushButton
        # Constructor
        #
        # @param partition [Y2Storage::Partition]
        def initialize(partition)
          textdomain "storage"

          @partition = partition
        end

        def label
          _("Edit...")
        end

        def opt
          [:key_F4]
        end

        def handle
          # Formerly:
          # EpEditPartition -> DlgEditPartition -> (MiniWorkflow:
          #   MiniWorkflowStepFormatMount, MiniWorkflowStepPassword)
          Sequences::EditBlkDevice.new(@partition).run

          # sym == :next ? :redraw : nil
          # must redraw because we've replaced the original dialog contents!
          :redraw
        end
      end
    end
  end
end
