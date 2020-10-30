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

require "y2partitioner/widgets/pages/devices_table"
require "y2partitioner/widgets/md_raids_table"
require "y2partitioner/widgets/md_add_button"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for Software RAIDs. It contains a {MdRaidsTable}.
      class MdRaids < DevicesTable
        extend Yast::I18n

        textdomain "storage"

        # Label for all the instances
        #
        # @see #label
        #
        # @return [String]
        def self.label
          _("RAID")
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
          MdAddButton.new
        end

        # @see DevicesTable
        def calculate_table
          MdRaidsTable.new(devices, pager, device_buttons)
        end

        # Returns all Software RAIDs and its partitions
        #
        # @return [Array<DeviceTableEntry>]
        def devices
          devicegraph = DeviceGraphs.instance.current
          devicegraph.software_raids.map do |raid|
            DeviceTableEntry.new_with_children(raid)
          end
        end
      end
    end
  end
end
