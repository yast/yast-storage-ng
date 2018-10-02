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
require "y2partitioner/widgets/pages/devices_table"
require "y2partitioner/widgets/md_raids_table"
require "y2partitioner/widgets/md_add_button"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for Software RAIDs. It contains a {MdRaidsTable}.
      class MdRaids < DevicesTable
        include Yast::I18n
        extend Yast::I18n

        # Constructor
        def initialize(*args)
          textdomain "storage"
          super
        end

        # Label for all the instances
        #
        # @see #label
        #
        # @return [String]
        def self.label
          N_("RAID")
        end

        # @macro seeAbstractWidget
        def label
          _(self.class.label)
        end

      private

        # @see DevicesTable
        def icon
          Icons::RAID
        end

        # @see DevicesTable
        def table_buttons
          MdAddButton.new
        end

        # @see DevicesTable
        def table
          @table ||= MdRaidsTable.new(devices, pager, device_buttons)
        end

        # Returns all Software RAIDs and its partitions
        #
        # @return [Array<Y2Storage::Md>]
        def devices
          devicegraph = DeviceGraphs.instance.current
          devicegraph.software_raids.each_with_object([]) do |raid, devices|
            devices << raid
            devices.concat(raid.partitions)
          end
        end
      end
    end
  end
end
