require "cwm/tree_pager"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/lvm_devices_table"

module Y2Partitioner
  module Widgets
    # A Page for LVM devices
    class LvmPage < CWM::Page
      include Yast::I18n
      extend Yast::I18n

      # Constructor
      #
      # @param pager [CWM::TreePager]
      def initialize(pager)
        textdomain "storage"

        @pager = pager
      end

      # Label for all the instances
      #
      # @see #label
      #
      # @return [String]
      def self.label
        _("Volume Management")
      end

      # @macro seeAbstractWidget
      def label
        self.class.label
      end

      # @macro seeCustomWidget
      def contents
        return @contents if @contents

        icon = Icons.small_icon(Icons::LVM)
        @contents = VBox(
          Left(
            HBox(
              Image(icon, ""),
              # TRANSLATORS: Heading
              Heading(_("Volume Management"))
            )
          ),
          LvmDevicesTable.new(devices, @pager)
        )
      end

    private

      # Returns all vgs and their lvs
      #
      # @return [Array<Y2Storage::LvmVg, Y2Storage::LvmLv>]
      def devices
        device_graph.lvm_vgs.reduce([]) do |devices, vg|
          devices << vg
          devices.concat(vg.lvm_lvs)
        end
      end

      def device_graph
        DeviceGraphs.instance.current
      end
    end
  end
end
