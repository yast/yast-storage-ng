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
      # Edit a partition
      # FIXME: this is NEARLY a duplicate of DiskPage::EditButton
      # but that one works with a table.
      # Analogous to DeleteDiskPartitionButton??
      class EditButton < CWM::PushButton
        # @param partition_name [String] FIXME: unsure which type we want
        def initialize(partition_name)
          # do we need this in every little tiny class?
          textdomain "storage"
          @partition_name = partition_name
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
          dg = DeviceGraphs.instance.current
          partition = Y2Storage::Partition.find_by_name(dg, @partition_name)

          Sequences::EditBlkDevice.new(partition).run

          # sym == :next ? :redraw : nil
          # must redraw because we've replaced the original dialog contents!
          :redraw
        end
      end

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
          EditButton.new(@partition.name),
          DeleteDiskPartitionButton.new(device: @partition)
        )
      end
    end
  end
end
