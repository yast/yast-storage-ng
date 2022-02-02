# Copyright (c) [2020] SUSE LLC
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
require "y2partitioner/widgets/tmpfs_filesystems_table"
require "y2partitioner/widgets/device_buttons_set"
require "y2partitioner/widgets/tmpfs_buttons"

module Y2Partitioner
  module Widgets
    module Pages
      # Page for Tmpfs filesystems
      class TmpfsFilesystems < DevicesTable
        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(pager)
          textdomain "storage"

          super
        end

        # @macro seeAbstractWidget
        def label
          _("Tmpfs")
        end

        private

        # @return [Array<Y2Storage::Filesystems::Tmpfs>]
        def devices
          device_graph.tmp_filesystems
        end

        # @see DevicesTable
        def table_buttons
          TmpfsAddButton.new
        end

        # @return [ConfigurableBlkDevicesTable]
        def calculate_table
          TmpfsFilesystemsTable.new(entries, pager, device_buttons)
        end

        # @return [Array<DeviceTableEntry>]
        def entries
          devices.map { |d| DeviceTableEntry.new(d) }
        end
      end
    end
  end
end
