require "yast"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/lvm_lv_attributes"

module Y2Partitioner
  module Widgets
    # Table widget to represent given list of Y2Storage::Mds together.
    class LvmDevicesTable < BlkDevicesTable
      include LvmLvAttributes

      # @param mds [Array<Y2Storage::Md>] devices to display
      # @param pager [CWM::Pager] table have feature, that double click change content of pager
      #   if someone do not need this feature, make it only optional
      def initialize(devices, pager)
        super
        add_columns(:pe_size, :stripes)
        remove_columns(:start_cyl, :end_cyl)
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
