require "cwm/tree_pager"

require "y2partitioner/widgets/delete_disk_partition_button"
require "y2partitioner/widgets/disk_table"
require "y2partitioner/icons"

module Y2Partitioner
  module Widgets
    # A Page for block devices: contains a {BlkDevicesTable}
    class BlkDevicesPage < CWM::Page
      include Yast::I18n

      def initialize(devices, pager)
        textdomain "storage"

        @devices = devices
        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("Hard Disks")
      end

      # @macro seeCustomWidget
      def contents
        return @contents if @contents

        icon = Icons.small_icon(Icons::HD)
        table = DiskTable.new(@devices, @pager)
        @contents = VBox(
          Left(
            HBox(
              Image(icon, ""),
              # TRANSLATORS: Heading. String followed by name of partition
              Heading(_("Hard Disks "))
            )
          ),
          table,
          HBox(
            # TODO: add and edit need to be also added
            DeleteDiskPartitionButton.new(
              device_graph: DeviceGraphs.instance.current,
              table:        table
            )
          )
        )
      end
    end
  end
end
