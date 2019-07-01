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

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for block disks and its partitions. It contains a {ConfigurableBlkDevicesTable}
      class Disks < DevicesTable
        include Yast::I18n

        # Constructor
        #
        # @param disks [Array<Y2Storage::BlkDevice>]
        # @param pager [CWM::TreePager]
        def initialize(disks, pager)
          textdomain "storage"

          super(pager)
          @disks = disks
        end

        # @macro seeAbstractWidget
        def label
          _("Hard Disks")
        end

        private

        # @return [Array<Y2Storage::BlkDevice>]
        attr_reader :disks

        # Returns all disks and their partitions
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def devices
          disks.each_with_object([]) do |disk, devices|
            devices << disk
            devices.concat(disk.partitions) if disk.respond_to?(:partitions)
          end
        end

        # @see DevicesTable
        def icon
          Icons::HD
        end
      end
    end
  end
end
