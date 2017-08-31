require "yast"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/lvm_lv_attributes"

module Y2Partitioner
  module Widgets
    # Table widget to represent a given list of LVM devices.
    class LvmDevicesTable < BlkDevicesTable
      include LvmLvAttributes

      # Constructor
      #
      # @param devices [Array<Y2Storage::Lvm_vg, Y2Storage::Lvm_lv>] devices to display
      # @param pager [CWM::Pager] table have feature, that double click change content of pager
      #   if someone do not need this feature, make it only optional
      def initialize(devices, pager)
        textdomain "storage"

        super
        add_columns(:pe_size, :stripes)
        remove_columns(:start, :end)
      end

    private

      def pe_size_title
        # TRANSLATORS: table header, type of metadata
        _("PE Size")
      end

      def stripes_title
        # TRANSLATORS: table header, number of LVM LV stripes
        _("Stripes")
      end

      def pe_size_value(device)
        return "" unless device.respond_to?(:extent_size)
        device.extent_size.to_human_string
      end

      def stripes_value(device)
        return "" unless devices.respond_to?(:stripes)
        stripes_info(device)
      end
    end
  end
end
