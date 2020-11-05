# Copyright (c) [2017-2020] SUSE LLC
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

require "y2partitioner/widgets/pages/devices_table"
require "y2partitioner/widgets/lvm_devices_table"
require "y2partitioner/widgets/device_add_buttons"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for LVM devices
      class Lvm < DevicesTable
        extend Yast::I18n

        textdomain "storage"

        # Label for all the instances
        #
        # @see #label
        #
        # @return [String]
        def self.label
          _("LVM Volume Groups")
        end

        # Constructor
        def initialize(*args)
          super
        end

        # @macro seeAbstractWidget
        def label
          self.class.label
        end

        private

        # @see DevicesTable
        def table_buttons
          LvmVgAddButton.new
        end

        # @see DevicesTable
        def calculate_table
          LvmDevicesTable.new(devices, pager, device_buttons)
        end

        # Returns all volume groups and their logical volumes, including thin pools
        # and thin volumes
        #
        # @see Y2Storage::LvmVg#all_lvm_lvs
        #
        # @return [Array<DeviceTableEntry>]
        def devices
          device_graph.lvm_vgs.map do |vg|
            DeviceTableEntry.new_with_children(vg)
          end
        end
      end
    end
  end
end
