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

require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/widgets/partition_add_button"
require "y2partitioner/widgets/blk_device_edit_button"
require "y2partitioner/widgets/partition_move_button"
require "y2partitioner/widgets/device_resize_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Widgets
    module Pages
      # A Page for block disks and its partitions. It contains a {ConfigurableBlkDevicesTable}
      class Disks < CWM::Page
        include Yast::I18n

        # Constructor
        #
        # @param disks [Array<Y2Storage::BlkDevice>]
        # @param pager [CWM::TreePager]
        def initialize(disks, pager)
          textdomain "storage"

          @disks = disks
          @pager = pager
        end

        # @macro seeAbstractWidget
        def label
          _("Hard Disks")
        end

        # @macro seeCustomWidget
        def contents
          return @contents if @contents

          table = ConfigurableBlkDevicesTable.new(devices, @pager)
          icon = Icons.small_icon(Icons::HD)
          @contents = VBox(
            Left(
              HBox(
                Image(icon, ""),
                # TRANSLATORS: Heading. String followed by name of partition
                Heading(_("Hard Disks "))
              )
            ),
            table,
            Left(
              HBox(
                # TODO: Add move button ?
                PartitionAddButton.new(pager: pager, table: table),
                BlkDeviceEditButton.new(pager: pager, table: table),
                PartitionMoveButton.new(pager: pager, table: table),
                DeviceResizeButton.new(pager: pager, table: table),
                DeviceDeleteButton.new(pager: pager, table: table)
              )
            )
          )
        end

      private

        # @return [Array<Y2Storage::BlkDevice>]
        attr_reader :disks

        # @return [CWM::TreePager]
        attr_reader :pager

        # Returns all disks and their partitions
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def devices
          disks.reduce([]) do |devices, disk|
            devices << disk
            devices.concat(disk.partitions)
          end
        end
      end
    end
  end
end
