require "cwm/widget"
require "y2partitioner/widgets/configurable_blk_devices_table"

module Y2Partitioner
  module Widgets
    # Class to represent a tab with a list of devices beloging to
    # a specific device (raid, multipath, etc)
    class UsedDevicesTab < CWM::Tab
      # Constructor
      #
      # @param devices [Array<Y2Storage::BlkDevice>]
      # @param pager [CWM::TreePager]
      def initialize(devices, pager)
        textdomain "storage"
        @devices = devices
        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("&Used Devices")
      end

      # @macro seeCustomWidget
      def contents
        @contents ||= VBox(table)
      end

    private

      # Returns a table with all devices used by a MD raid
      #
      # @return [ConfigurableBlkDevicesTable]
      def table
        return @table unless @table.nil?
        @table = ConfigurableBlkDevicesTable.new(@devices, @pager)
        @table.show_columns(:device, :size, :format, :encrypted, :type)
        @table
      end
    end
  end
end
