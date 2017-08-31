require "cwm/widget"
require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/device_graphs"
require "y2partitioner/sequences/add_partition"
require "y2partitioner/sequences/edit_blk_device"
require "y2partitioner/widgets/delete_disk_partition_button"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/disk_bar_graph"
require "y2partitioner/widgets/disk_description"

module Y2Partitioner
  module Widgets
    # A Page for a disk: contains {DiskTab} and {PartitionsTab}
    class DiskPage < CWM::Page
      attr_reader :disk

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
          CWM::Tabs.new(
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
        table = BlkDevicesTable.new(devices, @pager)
        @contents ||= VBox(
          DiskBarGraph.new(disk),
          table,
          HBox(
            AddButton.new(disk, table),
            EditButton.new(disk, table),
            DeleteDiskPartitionButton.new(
              device_graph: DeviceGraphs.instance.current,
              table:        table
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
        # @param table [BlkDevicesTable]
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

      # Edit a partition
      class EditButton < CWM::PushButton
        # Constructor
        #
        # @param disk [Y2Storage::Disk]
        # @param table [BlkDevicesTable]
        def initialize(disk, table)
          textdomain "storage"

          @disk = disk
          @table = table
        end

        def label
          _("Edit...")
        end

        def handle
          partition = @table.selected_device

          if partition.nil?
            Yast::Popup.Error(_("There are no partitions to edit."))
            return nil
          end

          Sequences::EditBlkDevice.new(partition).run

          # sym == :next ? :redraw : nil
          # must redraw because we've replaced the original dialog contents!
          :redraw
        end
      end
    end
  end
end
