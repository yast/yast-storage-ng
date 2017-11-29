require "cwm/pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/blk_device_edit_button"
require "y2partitioner/widgets/device_resize_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/widgets/partition_description"
require "y2partitioner/dialogs"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a partition
      class Partition < CWM::Page
        # Constructor
        #
        # @param [Y2Storage::Partition] partition
        def initialize(partition)
          textdomain "storage"

          @partition = partition
          self.widget_id = "partition:" + partition.name
        end

        # @return [Y2Storage::Partition] partition the page is about
        def device
          @partition
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
                BlkDeviceEditButton.new(device: @partition),
                DeviceResizeButton.new(device: @partition),
                DeviceDeleteButton.new(device: @partition)
              )
            )
          )
        end
      end
    end
  end
end
