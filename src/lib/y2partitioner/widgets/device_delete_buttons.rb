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
require "y2partitioner/actions/delete_partition"
require "y2partitioner/actions/delete_md"
require "y2partitioner/actions/delete_lvm_vg"
require "y2partitioner/actions/delete_lvm_lv"
require "y2partitioner/actions/delete_bcache"
require "y2partitioner/actions/delete_btrfs"
require "y2partitioner/actions/delete_btrfs_subvolume"

module Y2Partitioner
  module Widgets
    # Button for deleting a device
    class DeviceDeleteButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: label of the button for deleting a device
        _("Delete")
      end
    end

    # Button for deleting a partition
    class PartitionDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeletePartition.new(device)
      end
    end

    # Button for deleting a MD RAID
    class MdDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteMd.new(device)
      end
    end

    # Button for deleting a LVM Volume Group
    class LvmVgDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteLvmVg.new(device)
      end
    end

    # Button for deleting a LVM Logical Volume
    class LvmLvDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteLvmLv.new(device)
      end
    end

    # Button for deleting a Bcache
    class BcacheDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteBcache.new(device)
      end
    end

    # Button for deleting a Btrfs
    class BtrfsDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteBtrfs.new(device)
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
