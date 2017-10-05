require "cwm/widget"
require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/device_graphs"
require "y2partitioner/sequences/add_partition"
require "y2partitioner/widgets/delete_disk_partition_button"
require "y2partitioner/widgets/edit_blk_device_button"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/disk_bar_graph"
require "y2partitioner/widgets/disk_description"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a disk: contains {DiskTab} and {PartitionsTab}
      class Disk < CWM::Page
        # @return [Y2Storage::Device] Disk this page is about
        attr_reader :disk
        alias_method :device, :disk

        # Constructor
        #
        # @param disk [Y2Storage::Disk]
        # @param pager [CWM::TreePager]
        def initialize(disk, pager)
          textdomain "storage"

          @disk = disk
          @pager = pager
          self.widget_id = "disk:" + disk.name
        end

        # @macro seeAbstractWidget
        def label
          disk.basename
        end

        # @macro seeCustomWidget
        def contents
          icon = Icons.small_icon(Icons::HD)
          VBox(
            Left(
              HBox(
                Image(icon, ""),
                Heading(format(_("Hard Disk: %s"), disk.name))
              )
            ),
            Tabs.new(
              DiskTab.new(disk),
              PartitionsTab.new(disk, @pager)
            )
          )
        end
      end

      # A Tab for a disk
      class DiskTab < CWM::Tab
        # Constructor
        #
        # @param disk [Y2Storage::Disk]
        def initialize(disk)
          textdomain "storage"

          @disk = disk
        end

        # @macro seeAbstractWidget
        def label
          _("&Overview")
        end

        # @macro seeCustomWidget
        def contents
          # Page wants a WidgetTerm, not an AbstractWidget
          @contents ||= VBox(DiskDescription.new(@disk))
        end
      end

      # A Tab for disk partitions
      class PartitionsTab < CWM::Tab
        attr_reader :disk

        # Constructor
        #
        # @param disk [Y2Storage::Disk]
        # @param pager [CWM::TreePager]
        def initialize(disk, pager)
          textdomain "storage"

          @disk = disk
          @pager = pager
        end

        def initial
          true
        end

        # @macro seeAbstractWidget
        def label
          _("&Partitions")
        end

        # @macro seeCustomWidget
        def contents
          table = ConfigurableBlkDevicesTable.new(devices, @pager)
          @contents ||= VBox(
            DiskBarGraph.new(disk),
            table,
            Left(
              HBox(
                AddButton.new(disk, table),
                EditBlkDeviceButton.new(table: table),
                DeleteDiskPartitionButton.new(
                  device_graph: DeviceGraphs.instance.current,
                  table:        table
                )
              )
            )
          )
        end

      private

        def devices
          disk.partitions
        end

        # Add a partition
        class AddButton < CWM::PushButton
          # Constructor
          #
          # @param disk [Y2Storage::Disk]
          # @param table [ConfigurableBlkDevicesTable]
          def initialize(disk, table)
            textdomain "storage"

            @disk = disk
            @table = table
          end

          def label
            _("Add...")
          end

          def handle
            res = Sequences::AddPartition.new(@disk.name).run
            res == :finish ? :redraw : nil
          end
        end
      end
    end
  end
end
