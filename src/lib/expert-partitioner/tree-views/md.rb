
require "yast"
require "storage"
require "storage/storage-manager"
require "storage/extensions"
require "expert-partitioner/tree-views/view"
require "expert-partitioner/tab-views/md-overview"
require "expert-partitioner/tab-views/md-partitions"
require "expert-partitioner/tab-views/md-devices"
require "expert-partitioner/ui-extensions"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger


module ExpertPartitioner

  class MdTreeView < TreeView

    def initialize(md)
      @md = md
    end


    def create

      @tab_view = MdOverviewTabView.new(@md)

      tabs = [
        # tab heading
        Item(Id(:overview), _("&Overview")),
        # tab heading
        Item(Id(:partitions), _("&Partitions")),
        # tab heading
        Item(Id(:devices), _("&Used Devices"))
      ]

      VBox(
        Left(IconAndHeading(_("MD RAID: %s") % @md.name, Icons::MD)),
        DumbTab(Id(:tab), tabs, ReplacePoint(Id(:tab_panel), @tab_view.create()))
      )

    end


    def handle(input)

      @tab_view.handle(input)

      case input

      when :overview
        @tab_view = MdOverviewTabView.new(@md)

      when :partitions
        @tab_view = MdPartitionsTabView.new(@md)

      when :devices
        @tab_view = MdDevicesTabView.new(@md)

      end

      @tab_view.update()

    end

  end

end
