# Copyright (c) [2018-2022] SUSE LLC
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
require "y2partitioner/widgets/nfs_mounts_table"
require "y2partitioner/widgets/nfs_buttons"

module Y2Partitioner
  module Widgets
    module Pages
      # Page for NFS mounts
      class NfsMounts < DevicesTable
        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(pager)
          textdomain "storage"

          super
        end

        # @macro seeAbstractWidget
        def label
          _("NFS")
        end

        private

        # @return [Array<Y2Storage::Filesystems::Nfs>]
        def devices
          device_graph.nfs_mounts
        end

        # @return [ConfigurableBlkDevicesTable]
        def calculate_table
          NfsMountsTable.new(entries, pager, device_buttons)
        end

        # @see DevicesTable
        def table_buttons
          NfsAddButton.new
        end

        # @return [Array<DeviceTableEntry>]
        def entries
          devices.map { |d| DeviceTableEntry.new(d) }
        end
      end
    end
  end
end
