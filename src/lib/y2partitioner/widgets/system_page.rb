require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/rescan_devices_button"

Yast.import "Hostname"

module Y2Partitioner
  module Widgets
    # A Page for all storage devices in the system
    class SystemPage < CWM::Page
      include Yast::I18n

      # Constructor
      #
      # @param pager [CWM::TreePager]
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
          table,
          HBox(RescanDevicesButton.new)
        )
      end

    private

      attr_reader :hostname

      # The table contains all storage devices, including LVM Vgs
      #
      # @return [BlkDevicesTable]
      def table
        return @table unless @table.nil?
        @table = BlkDevicesTable.new(devices, @pager)
        @table.remove_columns(:start_cyl, :end_cyl)
        @table
      end

      # Returns all storage devices
      #
      # @note LVM Vgs are included.
      #
      # @return [Array<Y2Storage::Device>]
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
