# Copyright (c) [2019-2020] SUSE LLC
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
require "y2storage/filesystems/type"
require "y2partitioner/widgets/pages/devices_table"
require "y2partitioner/widgets/btrfs_filesystems_table"
require "y2partitioner/widgets/device_buttons_set"
require "y2partitioner/widgets/device_add_buttons"

module Y2Partitioner
  module Widgets
    module Pages
      # Page for Btrfs filesystems
      class BtrfsFilesystems < DevicesTable
        extend Yast::I18n

        textdomain "storage"

        # Label for all the instances
        #
        # @see #label
        #
        # @return [String]
        def self.label
          _("Btrfs")
        end

        # Constructor
        #
        # @param filesystems [Array<Y2Storage::Filesystems::Btrfs>]
        # @param pager [CWM::TreePager]
        def initialize(filesystems, pager)
          super(pager)

          @filesystems = filesystems
        end

        # @macro seeAbstractWidget
        def label
          self.class.label
        end

        private

        # @return [Array<Y2Storage::Filesystems::Btrfs>]
        attr_reader :filesystems

        # @see DevicesTable
        def table_buttons
          BtrfsAddButton.new
        end

        # @return [ConfigurableBlkDevicesTable]
        def calculate_table
          BtrfsFilesystemsTable.new(entries, pager, device_buttons)
        end

        # Widget with the dynamic set of buttons for the selected row
        #
        # @return [DeviceButtonsSet]
        def device_buttons
          @device_buttons ||= DeviceButtonsSet.new(pager)
        end

        # @return [Array<DeviceTableEntry>]
        def entries
          filesystems.map { |fs| DeviceTableEntry.new_with_children(fs) }
        end
      end
    end
  end
end
