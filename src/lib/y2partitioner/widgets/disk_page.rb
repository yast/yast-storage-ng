require "cwm/widget"
require "cwm/tree_pager"

require "y2partitioner/device_graphs"
require "y2partitioner/icons"
require "y2partitioner/sequences/add_partition"
require "y2partitioner/sequences/edit_blk_device"
require "y2partitioner/widgets/delete_disk_partition_button"
require "y2partitioner/widgets/disk_table"
require "y2partitioner/widgets/disk_bar_graph"
require "y2partitioner/widgets/disk_description"

module Y2Partitioner
  module Widgets
    # A Page for a disk: contains {DiskTab} and {PartitionsTab}
    class DiskPage < CWM::Page
      def initialize(disk_name, pager)
        textdomain "storage"
        @disk_name = disk_name
        @pager = pager
        self.widget_id = "disk:" + disk_name
      end

      def disk
        dg = DeviceGraphs.instance.current
        Y2Storage::Disk.find_by_name(dg, @disk_name)
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
              Heading(format(_("Hard Disk: %s"), @disk_name))
            )
          ),
          CWM::Tabs.new(
            DiskTab.new(disk),
            PartitionsTab.new(@disk_name, @pager)
          )
        )
      end
    end

    # A Tab for a disk
    class DiskTab < CWM::Tab
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
      # Add a partition
      class AddButton < CWM::PushButton
        # Y2Storage::Disk
        def initialize(disk_name)
          textdomain "storage"
          @disk_name = disk_name
        end

        def label
          _("Add...")
        end

        def handle
          res = Sequences::AddPartition.new(@disk_name).run
          res == :finish ? :redraw : nil
        end
      end

      # Edit a partition
      class EditButton < CWM::PushButton
        # Constructor
        #
        # @param disk [Y2Storage::Disk]
        # @param table [Y2Partitioner::Widgets::BlkDevicesTable]
        def initialize(disk, table)
          textdomain "storage"
          @disk = disk
          @table = table
        end

        def label
          _("Edit...")
        end

        def handle
          if @table.items.empty? || !@table.value
            Yast::Popup.Error(_("There are no partitions to edit."))
            return nil
          end

          name = @table.value[/table:partition:(.*)/, 1]
          partition = @disk.partitions.detect { |p| p.name == name }

          Sequences::EditBlkDevice.new(partition).run

          # sym == :next ? :redraw : nil
          # must redraw because we've replaced the original dialog contents!
          :redraw
        end
      end

      def initialize(disk_name, pager)
        textdomain "storage"
        @disk_name = disk_name
        @pager = pager
      end

      def disk
        dg = DeviceGraphs.instance.current
        Y2Storage::Disk.find_by_name(dg, @disk_name)
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
        @partitions_table = DiskTable.new(disk.partitions, @pager)
        @contents ||= VBox(
          DiskBarGraph.new(disk),
          @partitions_table,
          HBox(
            AddButton.new(@disk_name),
            EditButton.new(disk, @partitions_table),
            DeleteDiskPartitionButton.new(
              device_graph: DeviceGraphs.instance.current,
              table:        @partitions_table
            )
          )
        )
      end
    end
  end
end
