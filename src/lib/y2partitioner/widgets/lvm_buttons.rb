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

require "y2partitioner/widgets/action_button"
require "y2partitioner/widgets/device_button"
require "y2partitioner/widgets/device_add_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/actions/add_lvm_vg"
require "y2partitioner/actions/resize_lvm_vg"
require "y2partitioner/actions/delete_lvm_vg"
require "y2partitioner/actions/add_lvm_lv"
require "y2partitioner/actions/delete_lvm_lv"

module Y2Partitioner
  module Widgets
    # Button for opening a wizard to add a new LVM volume group
    class LvmVgAddButton < ActionButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: button label to add a LVM volume group
        _("Add Volume Group...")
      end

      # @see ActionButton#action
      def action
        Actions::AddLvmVg.new
      end
    end

    # Button for editing the list of physical volumes of an LVM VG
    class LvmVgResizeButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: label for button to change the list of physical volumes of an LVM VG
        _("Change...")
      end

      # @see ActionButton#action
      def action
        Actions::ResizeLvmVg.new(device)
      end
    end

    # Button for deleting a LVM Volume Group
    class LvmVgDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteLvmVg.new(device)
      end
    end

    # Button for opening the workflow to add a logical volume to a volume group
    class LvmLvAddButton < DeviceAddButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: button label to add a logical volume
        _("Add Logical Volume...")
      end

      # When the selected device is a logical volume, its volume group is considered as the selected
      # device.
      #
      # @see DeviceAddButton#device
      def device_or_parent(device)
        return device.lvm_vg if device.is?(:lvm_lv)

        device
      end

      # @see ActionButton#action
      def action
        Actions::AddLvmLv.new(device)
      end
    end

    # Button for deleting a LVM Logical Volume
    class LvmLvDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteLvmLv.new(device)
      end
    end
  end
end
