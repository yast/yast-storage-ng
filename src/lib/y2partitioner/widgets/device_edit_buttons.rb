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

require "y2partitioner/widgets/device_button"
require "y2partitioner/actions/add_lvm_lv"
require "y2partitioner/actions/edit_blk_device"
require "y2partitioner/actions/edit_btrfs"
require "y2partitioner/actions/edit_bcache"
require "y2partitioner/actions/edit_md_devices"
require "y2partitioner/actions/edit_btrfs_devices"
require "y2partitioner/actions/resize_lvm_vg"
require "y2partitioner/actions/edit_btrfs_subvolume"

module Y2Partitioner
  module Widgets
    # Device button for editing a device
    class DeviceEditButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: label for the button to edit a device
        _("&Edit...")
      end
    end

    # Button for editing a block device
    class BlkDeviceEditButton < DeviceEditButton
      # @see ActionButton#action
      def action
        Actions::EditBlkDevice.new(device)
      end
    end

    # Button for editing a Btrfs filesystem
    class BtrfsEditButton < DeviceEditButton
      # @see ActionButton#action
      def action
        Actions::EditBtrfs.new(device)
      end
    end

    # Button for editing a Btrfs subvolume
    class BtrfsSubvolumeEditButton < DeviceEditButton
      # @see ActionButton#action
      def action
        Actions::EditBtrfsSubvolume.new(device)
      end
    end

    # Button for editing a Bcache
    class BcacheEditButton < DeviceEditButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: label for the button to edit a Bcache
        _("Change Caching...")
      end

      # @see ActionButton#action
      def action
        Actions::EditBcache.new(device)
      end
    end

    # Button for editing the used devices of a Software RAID
    class MdDevicesEditButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: label for button to edit the used devices
        _("Change...")
      end

      # @see ActionButton#action
      def action
        Actions::EditMdDevices.new(device)
      end
    end

    # Button for editing the used devices of a Btrfs filesystem
    class BtrfsDevicesEditButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: label for button to edit the used devices
        _("Change...")
      end

      # @see ActionButton#action
      def action
        Actions::EditBtrfsDevices.new(device)
      end
    end

    # Button for editing the list of physical volumes of an LVM VG
    class LvmVgResizeButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: label for button to change the list of physical volumes of an LVM VG
        _("Change...")
      end

      # @see ActionButton#action
      def action
        Actions::ResizeLvmVg.new(device)
      end
    end
  end
end
