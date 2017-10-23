# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "cwm/widget"
require "cwm/tree_pager"
require "y2partitioner/widgets/tabs"
require "y2partitioner/icons"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/lvm_devices_table"
require "y2partitioner/widgets/lvm_vg_bar_graph"
require "y2partitioner/widgets/lvm_vg_description"
require "y2partitioner/widgets/add_lvm_lv_button"
require "y2partitioner/widgets/edit_lvm_button"
require "y2partitioner/widgets/resize_lvm_button"
require "y2partitioner/widgets/delete_lvm_button"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for a LVM Volume Group. It contains several tabs.
      class LvmVg < CWM::Page
        # Constructor
        #
        # @param lvm_vg [Y2Storage::Lvm_vg]
        # @param pager [CWM::TreePager]
        def initialize(lvm_vg, pager)
          textdomain "storage"

          @lvm_vg = lvm_vg
          @pager = pager
          self.widget_id = "lvm_vg:" + lvm_vg.vg_name
        end

        # @return [Y2Storage::LvmVg] volume group the page is about
        def device
          @lvm_vg
        end

        # @macro seeAbstractWidget
        def label
          @lvm_vg.vg_name
        end

        # @macro seeCustomWidget
        def contents
          icon = Icons.small_icon(Icons::LVM)
          VBox(
            Left(
              HBox(
                Image(icon, ""),
                Heading(format(_("Volume Group: %s"), "/dev/" + @lvm_vg.vg_name))
              )
            ),
            Tabs.new(
              LvmVgTab.new(@lvm_vg),
              LvmLvTab.new(@lvm_vg, @pager),
              LvmPvTab.new(@lvm_vg, @pager)
            )
          )
        end
      end

      # A Tab for a LVM Volume Group info
      class LvmVgTab < CWM::Tab
        # Constructor
        #
        # @param lvm_vg [Y2Storage::Lvm_vg]
        def initialize(lvm_vg)
          textdomain "storage"

          @lvm_vg = lvm_vg
        end

        # @macro seeAbstractWidget
        def label
          _("&Overview")
        end

        # @macro seeCustomWidget
        def contents
          # Page wants a WidgetTerm, not an AbstractWidget
          @contents ||= VBox(LvmVgDescription.new(@lvm_vg))
        end
      end

      # A Tab for the LVM logical volumes of a volume group
      class LvmLvTab < CWM::Tab
        # Constructor
        #
        # @param lvm_vg [Y2Storage::Lvm_vg]
        # @param pager [CWM::TreePager]
        def initialize(lvm_vg, pager)
          textdomain "storage"

          @lvm_vg = lvm_vg
          @pager = pager
        end

        # @macro seeAbstractWidget
        def label
          _("Log&ical Volumes")
        end

        # Selects this tab by default
        def initial
          true
        end

        # @macro seeCustomWidget
        def contents
          @contents ||= VBox(
            LvmVgBarGraph.new(@lvm_vg),
            table,
            Left(
              HBox(
                AddLvmLvButton.new(@lvm_vg),
                EditLvmButton.new(table: table),
                ResizeLvmButton.new(table: table),
                DeleteLvmButton.new(table: table)
              )
            )
          )
        end

      private

        # Returns a table with all logical volumes of a volume group
        #
        # @return [LvmDevicesTable]
        def table
          return @table unless @table.nil?
          @table = LvmDevicesTable.new(devices, @pager)
          @table.remove_columns(:pe_size)
          @table
        end

        def devices
          @lvm_vg.lvm_lvs
        end
      end

      # A Tab for the LVM physical volumes of a volume group
      class LvmPvTab < CWM::Tab
        # Constructor
        #
        # @param lvm_vg [Y2Storage::Lvm_vg]
        # @param pager [CWM::TreePager]
        def initialize(lvm_vg, pager)
          textdomain "storage"

          @lvm_vg = lvm_vg
          @pager = pager
        end

        # @macro seeAbstractWidget
        def label
          _("&Physical Volumes")
        end

        # @macro seeCustomWidget
        def contents
          # Page wants a WidgetTerm, not an AbstractWidget
          @contents ||= VBox(table)
        end

      private

        # Returns a table with all physical volumes of a volume group
        #
        # @return [ConfigurableBlkDevicesTable]
        def table
          return @table unless @table.nil?
          @table = ConfigurableBlkDevicesTable.new(devices, @pager)
          @table.show_columns(:device, :size, :format, :encrypted, :type)
          @table
        end

        def devices
          @lvm_vg.lvm_pvs.map(&:plain_blk_device)
        end
      end
    end
  end
end
