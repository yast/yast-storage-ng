require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/delete_disk_partition_button"
require "y2partitioner/widgets/blk_devices_table"

module Y2Partitioner
  module Widgets
    # A Page for block disks and its partitions. It contains a {BlkDevicesTable}
    class DisksPage < CWM::Page
      include Yast::I18n

      # Constructor
      #
      # @param pager [CWM::TreePager]
      def initialize(pager)
        textdomain "storage"

        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("Hard Disks")
      end

      # @macro seeCustomWidget
      def contents
        return @contents if @contents

        table = BlkDevicesTable.new(devices, @pager)
        icon = Icons.small_icon(Icons::HD)
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
              devicegraph: devicegraph,
              table:       table
            )
          )
        )
      end

    private

      # Returns all disks and their partitions
      #
      # @return [Array<Y2Storage::BlkDevice>]
      def devices
        devicegraph.disks.reduce([]) do |devices, disk|
          devices << disk
          devices.concat(disk.partitions)
        end
      end

      def devicegraph
        DeviceGraphs.instance.current
      end
    end
  end
end
