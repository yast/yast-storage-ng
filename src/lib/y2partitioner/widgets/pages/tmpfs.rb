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

require "y2partitioner/widgets/pages/devices_table"
require "y2partitioner/widgets/tmpfs_filesystems_table"
require "y2partitioner/widgets/device_buttons_set"

module Y2Partitioner
  module Widgets
    module Pages
      # Page for a Tmpfs filesystem
      class Tmpfs < DevicesTable
        # @return [Y2Storage::Filesystems::Tmpfs]
        attr_reader :filesystem

        # Needed for searching a device page, see {OverviewTreePager#device_page}
        alias_method :device, :filesystem

        # Constructor
        #
        # @param pager [CWM::TreePager]
        def initialize(filesystem, pager)
          textdomain "storage"

          super(pager)

          @filesystem = filesystem
          self.widget_id = "tmpfs:" + filesystem.sid.to_s
        end

        # @macro seeAbstractWidget
        def label
          filesystem.mount_path
        end

        private

        # @return [ConfigurableBlkDevicesTable]
        def calculate_table
          TmpfsFilesystemsTable.new(entries, pager, device_buttons)
        end

        # Widget with the dynamic set of buttons for the selected row
        #
        # @return [DeviceButtonsSet]
        def device_buttons
          @device_buttons ||= DeviceButtonsSet.new(pager)
        end

        # @return [Array<DeviceTableEntry>]
        def entries
          [DeviceTableEntry.new(filesystem)]
        end
      end
    end
  end
end
