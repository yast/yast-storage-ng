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
require "y2partitioner/widgets/device_edit_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/actions/add_btrfs"
require "y2partitioner/actions/edit_btrfs"
require "y2partitioner/actions/edit_btrfs_devices"
require "y2partitioner/actions/delete_btrfs"
require "y2partitioner/actions/add_btrfs_subvolume"
require "y2partitioner/actions/edit_btrfs_subvolume"
require "y2partitioner/actions/delete_btrfs_subvolume"

module Y2Partitioner
  module Widgets
    # Button for opening a wizard to add a new Btrfs filesystem
    class BtrfsAddButton < ActionButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: button label to add a new Btrfs filesystem
        _("Add Btrfs...")
      end

      # @see ActionButton#action
      def action
        Actions::AddBtrfs.new
      end
    end

    # Button for editing a Btrfs filesystem
    class BtrfsEditButton < DeviceEditButton
      # @see ActionButton#action
      def action
        Actions::EditBtrfs.new(device)
      end
    end

    # Button for editing the used devices of a Btrfs filesystem
    class BtrfsDevicesEditButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: label for button to edit the used devices
        _("Change...")
      end

      # @see ActionButton#action
      def action
        Actions::EditBtrfsDevices.new(device)
      end
    end

    # Button for deleting a Btrfs filesystem
    class BtrfsDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteBtrfs.new(device)
      end
    end

    # Button for adding a new Btrfs subvolume
    class BtrfsSubvolumeAddButton < DeviceAddButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: button label to add a logical volume
        _("Add Subvolume...")
      end

      # Always returns the filesystem associated to the given device
      #
      # @see DeviceAddButton#device
      def device_or_parent(device)
        return device if device.is?(:btrfs)

        device.filesystem
      end

      # @see ActionButton#action
      def action
        Actions::AddBtrfsSubvolume.new(device)
      end
    end

    # Button for editing a Btrfs subvolume
    class BtrfsSubvolumeEditButton < DeviceEditButton
      # @see ActionButton#action
      def action
        Actions::EditBtrfsSubvolume.new(device)
      end
    end

    # Button for deleting a Btrfs subvolume
    class BtrfsSubvolumeDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteBtrfsSubvolume.new(device)
      end
    end
  end
end
