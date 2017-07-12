require "yast"

require "cwm/table"

require "y2partitioner/icons"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/help"
require "y2partitioner/widgets/used_devices_table"

module Y2Partitioner
  module Widgets
    # Table widget to represent used devices by given Y2Storage::Md.
    class MdUsedDevicesTable < UsedDevicesTable
      # @param md [Y2Storage::LvmMd] device to display
      # @param pager [CWM::Pager] table have feature, that double click change content of pager
      #   if someone do not need this feature, make it only optional
      def initialize(md, pager)
        textdomain "storage"
        @md = md
        @pager = pager
        super(pager)
      end

      def blk_devices
        @md.devices
      end

      # @macro seeAbstractWidget
      def help
        header = _(
          "<p><p>This view shows all devices used by the\nselected RAID.</p>"
        )
        header + super
      end
    end
  end
end
