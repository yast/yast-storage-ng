require "cwm/pager"

require "y2partitioner/widgets/lvm_table"

module Y2Partitioner
  module Widgets
    # A Page for for given list of Y2Storage::LvmLV|Y2Storage::LvmVG.
    class LvmPage < CWM::Page
      # @param [Y2Storage::LvmLV|Y2Storage::LvmVG] devices to display
      def initialize(devices, pager)
        textdomain "storage"

        @devices = devices
        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("Volume Management")
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
          LvmTable.new(@devices, @pager)
        )
      end
    end
  end
end
