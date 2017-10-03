require "cwm/pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/delete_disk_partition_button"
require "y2partitioner/widgets/edit_blk_device_button"
require "y2partitioner/widgets/partition_description"
require "y2partitioner/dialogs/format_and_mount"

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
          Left(
            HBox(
              EditBlkDeviceButton.new(device: @partition),
              DeleteDiskPartitionButton.new(device: @partition)
            )
          )
        )
      end
    end
  end
end
