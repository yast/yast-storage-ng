# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/icons"
require "y2partitioner/widgets/pages/devices_table"
require "y2partitioner/widgets/btrfs_filesystems_table"
require "y2partitioner/widgets/btrfs_add_button"
require "y2partitioner/widgets/device_buttons_set"
require "y2storage/filesystems/type"

module Y2Partitioner
  module Widgets
    module Pages
      # Page for BTRFS filesystems
      class BtrfsFilesystems < DevicesTable
        # Constructor
        #
        # @param filesystems [Array<Y2Storage::Filesystems::Btrfs>]
        # @param pager [CWM::TreePager]
        def initialize(filesystems, pager)
          textdomain "storage"

          super(pager)

          @filesystems = filesystems
        end

        # @macro seeAbstractWidget
        def label
          _("Btrfs")
        end

      private

        # @return [Array<Y2Storage::Filesystems::Btrfs>]
        attr_reader :filesystems

        # @see DevicesTable
        def icon
          Icons::BTRFS
        end

        # @see DevicesTable
        def table_buttons
          BtrfsAddButton.new
        end

        # @return [ConfigurableBlkDevicesTable]
        def table
          @table ||= BtrfsFilesystemsTable.new(filesystems, pager, device_buttons)
        end

        # Widget with the dynamic set of buttons for the selected row
        #
        # @return [DeviceButtonsSet]
        def device_buttons
          @device_buttons ||= DeviceButtonsSet.new(pager)
        end
      end
    end
  end
end
