# encoding: utf-8

# Copyright (c) [2015-2016] SUSE LLC
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
require "expert_partitioner/tab_views/lvm_vg/overview"
require "expert_partitioner/tab_views/lvm_vg/lvm_lvs"
require "expert_partitioner/tab_views/lvm_vg/lvm_pvs"
require "expert_partitioner/ui_extensions"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger

module ExpertPartitioner
  class LvmVgTreeView < TreeView
    def initialize(lvm_vg)
      @lvm_vg = lvm_vg
    end

    def create
      @tab_view = LvmVgOverviewTabView.new(@lvm_vg)

      tabs = [
        # tab heading
        Item(Id(:overview), _("&Overview")),
        # tab heading
        Item(Id(:lvm_lvs), _("&LVM LVs")),
        # tab heading
        Item(Id(:lvm_pvs), _("&LVM PVs"))
      ]

      VBox(
        Left(IconAndHeading(_("LVM VG: %s") % @lvm_vg.vg_name, Icons::LVM_VG)),
        DumbTab(Id(:tab), tabs, ReplacePoint(Id(:tab_panel), @tab_view.create))
      )
    end

    def handle(input)
      @tab_view.handle(input)

      case input

      when :overview
        @tab_view = LvmVgOverviewTabView.new(@lvm_vg)

      when :lvm_lvs
        @tab_view = LvmVgLvmLvsTabView.new(@lvm_vg)

      when :lvm_pvs
        @tab_view = LvmVgLvmPvsTabView.new(@lvm_vg)

      end

      @tab_view.update
    end
  end
end
