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

require "y2partitioner/icons"
require "y2partitioner/ui_state"
require "y2partitioner/widgets/pages/devices_table"
require "y2partitioner/widgets/lvm_devices_table"
require "y2partitioner/widgets/lvm_vg_add_button"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for LVM devices
      class Lvm < DevicesTable
        include Yast::I18n

        # Constructor
        def initialize(*args)
          textdomain "storage"
          super
        end

        # @macro seeAbstractWidget
        def label
          UIState.instance.lvm_label
        end

      private

        # @see DevicesTable
        def icon
          Icons::LVM
        end

        # @see DevicesTable
        def table_buttons
          LvmVgAddButton.new
        end

        # @see DevicesTable
        def table
          @table ||= LvmDevicesTable.new(devices, pager, device_buttons)
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
      end
    end
  end
end
