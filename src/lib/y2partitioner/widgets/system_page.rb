require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/blk_devices_table"

Yast.import "Hostname"

module Y2Partitioner
  module Widgets
    # A Page for block devices: contains a {BlkDevicesTable}
    class SystemPage < CWM::Page
      include Yast::I18n

      def initialize(pager)
        textdomain "storage"

        @pager = pager
        @hostname = Yast::Hostname.CurrentHostname
      end

      # @macro seeAbstractWidget
      def label
        hostname
      end

      # @macro seeCustomWidget
      def contents
        return @contents if @contents

        icon = Icons.small_icon(Icons::ALL)
        @contents = VBox(
          Left(
            HBox(
              Image(icon, ""),
              # TRANSLATORS: Heading. String followed by name of partition
              Heading(format(_("Available Storage on %s"), hostname))
            )
          ),
          table
        )
      end

    private

      attr_reader :hostname

      def table
        return @table unless @table.nil?
        @table = BlkDevicesTable.new(devices, @pager)
        @table.remove_columns(:start_cyl, :end_cyl)
        @table
      end

      def devices
        disk_devices + lvm_vgs
      end

      def disk_devices
        devicegraph.disk_devices.reduce([]) do |devices, disk|
          devices << disk
          devices.concat(disk.partitions)
        end
      end

      def lvm_vgs
        devicegraph.lvm_vgs.reduce([]) do |devices, vg|
          devices << vg
          devices.concat(vg.lvm_lvs)
        end
      end

      def devicegraph
        DeviceGraphs.instance.current
      end
    end
  end
end
