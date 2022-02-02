# Copyright (c) [2022] SUSE LLC
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

module Y2Partitioner
  module Widgets
    module Pages
      # Page for an NFS mount
      class Nfs < DevicesTable
        # @return [Y2Storage::Filesystems::Nfs]
        attr_reader :mount

        # Needed for searching a device page, see {OverviewTreePager#device_page}
        alias_method :device, :mount

        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(mount, pager)
          textdomain "storage"

          super(pager)

          @mount = mount
          self.widget_id = "nfs:" + mount.sid.to_s
        end

        # @macro seeAbstractWidget
        def label
          # The name (server + remote path) is usually too long, better use something sorter
          mount.mount_path
        end

        private

        # @return [ConfigurableBlkDevicesTable]
        def calculate_table
          NfsMountsTable.new(entries, pager, device_buttons)
        end

        # Widget with the dynamic set of buttons for the selected row
        #
        # @return [DeviceButtonsSet]
        def device_buttons
          @device_buttons ||= DeviceButtonsSet.new(pager)
        end

        # @return [Array<DeviceTableEntry>]
        def entries
          [DeviceTableEntry.new(mount)]
        end
      end
    end
  end
end
