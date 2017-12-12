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

require "yast"
require "cwm"
require "y2partitioner/actions/edit_blk_device"
require "y2partitioner/widgets/device_button"
require "y2partitioner/ui_state"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Button for editing a block device
    class BlkDeviceEditButton < DeviceButton
      def label
        # TRANSLATORS: button label for editing a block device
        _("Edit...")
      end

    private

      # @see DeviceButton#actions
      # When the device is a disk, dasd, multipath or bios raid, edit means
      # to jump to the tree page of that device. For partition or software
      # raid, the editing workflow to select mount and format options is shown.
      def actions
        UIState.instance.select_row(device.sid)
        partition? || software_raid? ? super : go_to_disk_page
      end

      # Whether the device is a partition
      #
      # @return [Booelan]
      def partition?
        device.is?(:partition)
      end

      # Whether the device is a software raid
      #
      # @return [Booelan]
      def software_raid?
        device.is?(:md) && device.software_defined?
      end

      # If pager is known, jumps to the disk device page
      def go_to_disk_page
        return unless pager

        page = pager.device_page(device)
        UIState.instance.go_to_tree_node(page)
        :redraw
      end

      # Returns the proper Actions class for editing
      #
      # @see Actions::EditBlkDevice
      def actions_class
        Actions::EditBlkDevice
      end
    end
  end
end
