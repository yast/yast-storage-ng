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

require "storage/extensions"
require "expert_partitioner/tree_views/view"
require "expert_partitioner/tab_views/md/overview"
require "expert_partitioner/tab_views/md/partitions"
require "expert_partitioner/tab_views/md/devices"
require "expert_partitioner/ui_extensions"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger

module ExpertPartitioner
  class MdTreeView < TreeView
    def initialize(md)
      textdomain "storage-ng"
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
        DumbTab(Id(:tab), tabs, ReplacePoint(Id(:tab_panel), @tab_view.create))
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

      @tab_view.update
    end
  end
end
