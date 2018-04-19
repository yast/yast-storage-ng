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

require "cwm/tree_pager"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/lvm_devices_table"
require "y2partitioner/widgets/lvm_add_button"
require "y2partitioner/widgets/lvm_edit_button"
require "y2partitioner/widgets/device_resize_button"
require "y2partitioner/widgets/device_delete_button"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for LVM devices
      class Lvm < CWM::Page
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
          N_("Volume Management")
        end

        # @macro seeAbstractWidget
        def label
          _(self.class.label)
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
            table,
            Left(
              HBox(
                LvmAddButton.new(table),
                LvmEditButton.new(pager: @pager, table: table),
                DeviceResizeButton.new(pager: @pager, table: table),
                DeviceDeleteButton.new(pager: @pager, table: table)
              )
            )
          )
        end

      private

        # Table with all vgs and their lvs
        #
        # @return [LvmDevicesTable]
        def table
          @table ||= LvmDevicesTable.new(devices, @pager)
        end

        # Returns all volume groups and their logical volumes, including thin pools
        # and thin volumes
        #
        # @see Y2Storage::LvmVg#all_lvm_lvs
        #
        # @return [Array<Y2Storage::LvmVg, Y2Storage::LvmLv>]
        def devices
          device_graph.lvm_vgs.reduce([]) do |devices, vg|
            devices << vg
            devices.concat(vg.all_lvm_lvs)
          end
        end

        def device_graph
          DeviceGraphs.instance.current
        end
      end
    end
  end
end
