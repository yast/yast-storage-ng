
require "yast"
require "storage"
require "storage/extensions"
require "expert-partitioner/tree-views/view"
require "expert-partitioner/tab-views/disk-overview"
require "expert-partitioner/tab-views/disk-partitions"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger


module ExpertPartitioner

  class DiskTreeView < TreeView

    def initialize(disk)
      @disk = disk
    end


    def create

      @tab_view = DiskOverviewTabView.new(@disk)

      tabs = [
        # tab heading
        Item(Id(:overview), _("&Overview")),
        # tab heading
        Item(Id(:partitions), _("&Partitions"))
      ]

      VBox(
        Left(IconAndHeading(_("Hard Disk: %s") % @disk.name, Icons::DISK)),
        DumbTab(Id(:tab), tabs, ReplacePoint(Id(:tab_panel), @tab_view.create()))
      )

    end


    def handle(input)

      @tab_view.handle(input)

      case input

      when :overview
        @tab_view = DiskOverviewTabView.new(@disk)

      when :partitions
        @tab_view = DiskPartitionsTabView.new(@disk)

      end

      @tab_view.update()

    end

  end

end
