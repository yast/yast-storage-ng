require "cwm/widget"
require "cwm/tree_pager"

require "y2partitioner/device_graphs"
require "y2partitioner/icons"
require "y2partitioner/widgets/md_description"
require "y2partitioner/widgets/md_used_devices_table"

module Y2Partitioner
  module Widgets
    # A Page for a md raid device: contains {MdTab} and {MdUsedDevicesTab}
    class MdRaidPage < CWM::Page
      def initialize(md, pager)
        textdomain "storage"
        @md = md
        @pager = pager
        self.widget_id = "md:" + @md.name
      end

      # @macro seeAbstractWidget
      def label
        @md.basename
      end

      # @macro seeCustomWidget
      def contents
        icon = Icons.small_icon(Icons::RAID)
        VBox(
          Left(
            HBox(
              Image(icon, ""),
              Heading(format(_("RAID: %s"), @md.name))
            )
          ),
          CWM::Tabs.new(
            MdTab.new(@md),
            MdUsedDevicesTab.new(@md, @pager)
          )
        )
      end
    end

    # A Tab for a Md raid description
    class MdTab < CWM::Tab
      def initialize(md)
        textdomain "storage"
        @md = md
      end

      def initial
        true
      end

      # @macro seeAbstractWidget
      def label
        _("&Overview")
      end

      # @macro seeCustomWidget
      def contents
        # Page wants a WidgetTerm, not an AbstractWidget
        @contents ||= VBox(MdDescription.new(@md))
      end
    end

    # A Tab for devices used by given md raid device
    class MdUsedDevicesTab < CWM::Tab
      def initialize(md, pager)
        textdomain "storage"
        @md = md
        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("&Used Devices")
      end

      # @macro seeCustomWidget
      def contents
        @contents ||= VBox(MdUsedDevicesTable.new(@md, @pager))
      end
    end
  end
end
