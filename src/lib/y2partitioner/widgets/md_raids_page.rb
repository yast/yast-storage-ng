require "cwm/tree_pager"

require "y2partitioner/widgets/md_raid_table"
require "y2partitioner/icons"

module Y2Partitioner
  module Widgets
    # A Page for md raids: contains a {MdRaidTable}
    class MdRaidsPage < CWM::Page
      include Yast::I18n

      def initialize(devices, pager)
        textdomain "storage"

        @devices = devices
        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("RAID")
      end

      # @macro seeCustomWidget
      def contents
        return @contents if @contents

        icon = Icons.small_icon(Icons::RAID)
        @contents = VBox(
          Left(
            HBox(
              Image(icon, ""),
              # TRANSLATORS: Heading
              Heading(_("RAID"))
            )
          ),
          MdRaidTable.new(@devices, @pager)
        )
      end
    end
  end
end
