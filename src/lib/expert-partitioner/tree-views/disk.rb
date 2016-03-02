# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

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
        DumbTab(Id(:tab), tabs, ReplacePoint(Id(:tab_panel), @tab_view.create))
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

      @tab_view.update
    end
  end
end
