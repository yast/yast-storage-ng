# Copyright (c) [2018-2020] SUSE LLC
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
require "y2partitioner/widgets/pages/devices_table"
require "y2partitioner/widgets/device_add_buttons"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/device_table_entry"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for bcache devices
      #
      # It contains a table with a list of all bcache devices
      class Bcaches < DevicesTable
        extend Yast::I18n

        textdomain "storage"

        # Label for all the instances
        #
        # @see #label
        #
        # @return [String]
        def self.label
          _("Bcache Devices")
        end

        # @macro seeAbstractWidget
        def label
          self.class.label
        end

        private

        # @see DevicesTable
        def table_buttons
          BcacheAddButton.new
        end

        # Entries for all bcache devices and their partitions
        #
        # @return [Array<DeviceTableEntry>]
        def devices
          devicegraph = DeviceGraphs.instance.current
          devicegraph.bcaches.map do |bcache|
            DeviceTableEntry.new_with_children(bcache)
          end
        end
      end
    end
  end
end
