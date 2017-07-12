require "yast"

require "cwm/table"

require "y2partitioner/icons"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/help"
require "y2partitioner/widgets/used_devices_table"

module Y2Partitioner
  module Widgets
    # Table widget to represent given list of Y2Storage::LvmLvs together.
    class LvmPvTable < UsedDevicesTable
      include BlkDevicesTable
      include Help

      # @param pvs [Array<Y2Storage::LvmPv] devices to display
      # @param pager [CWM::Pager] table have feature, that double click change content of pager
      #   if someone do not need this feature, make it only optional
      def initialize(pvs, pager)
        textdomain "storage"
        @pvs = pvs
        @pager = pager
        super(pager)
      end

      def blk_devices
        @pvs.map(&:plain_blk_device)
      end

      # @macro seeAbstractWidget
      def help
        header = _(
          "<p>This view shows all physical volumes used by\nthe selected volume group.</p>"
        )
        header + super
      end
    end
  end
end
