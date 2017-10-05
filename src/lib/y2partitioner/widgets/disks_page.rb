require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/delete_disk_partition_button"
require "y2partitioner/widgets/configurable_blk_devices_table"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for block disks and its partitions. It contains a {ConfigurableBlkDevicesTable}
      class Disks < CWM::Page
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

          table = ConfigurableBlkDevicesTable.new(devices, @pager)
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
                device_graph: device_graph,
                table:        table
              )
            )
          )
        end

      private

        # Returns all disks and their partitions
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def devices
          device_graph.disks.reduce([]) do |devices, disk|
            devices << disk
            devices.concat(disk.partitions)
          end
        end

        def device_graph
          DeviceGraphs.instance.current
        end
      end
    end
  end
end
