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

require "abstract_method"
require "y2partitioner/widgets/action_button"
require "y2partitioner/widgets/device_button"
require "y2partitioner/actions/add_md"
require "y2partitioner/actions/add_lvm_vg"
require "y2partitioner/actions/add_bcache"
require "y2partitioner/actions/add_btrfs"
require "y2partitioner/actions/add_partition"
require "y2partitioner/actions/add_lvm_lv"
require "y2partitioner/actions/add_btrfs_subvolume"

module Y2Partitioner
  module Widgets
    # Button for opening a wizard to add a new MD array
    class MdAddButton < ActionButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to add a MD Raid
        _("Add RAID...")
      end

      # @see ActionButton#actions
      def action
        Actions::AddMd.new
      end
    end

    # Button for opening a wizard to add a new LVM volume group
    class LvmVgAddButton < ActionButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to add a LVM volume group
        _("Add Volume Group...")
      end

      # @see ActionButton#action
      def action
        Actions::AddLvmVg.new
      end
    end

    # Button for opening a wizard to add a new Bcache device
    class BcacheAddButton < ActionButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to add a new Bcache device
        _("Add Bcache...")
      end

      # @see ActionButton#action
      def action
        Actions::AddBcache.new
      end
    end

    # Button for opening a wizard to add a new Bcache device
    class BtrfsAddButton < ActionButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to add a new Bcache device
        _("Add Btrfs...")
      end

      # @see ActionButton#action
      def action
        Actions::AddBtrfs.new
      end
    end

    # Base class of buttons for adding a device to a given device
    class DeviceAddButton < DeviceButton
      # @see DeviceButton#initialize
      def initialize(args = {})
        super(**args)
        textdomain "storage"
      end

      # @see DeviceButton#device
      def device
        dev = super
        return unless dev

        device_or_parent(dev)
      end

      # @!method device_or_parent(device)
      #   Finds the correct device for the action
      #
      #   @param device [Y2Storage::Device]
      #   @return [Y2Storage::Device]
      abstract_method :device_or_parent
    end

    # Button for adding a partition
    class PartitionAddButton < DeviceAddButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: label for button to add a partition
        _("Add Partition...")
      end

      # When the selected device is a partition, its partitionable (disk, dasd, multipath or BIOS RAID)
      # is considered as the selected device.
      #
      # @see DeviceAddButton#device
      def device_or_parent(device)
        return device.partitionable if device.is?(:partition)

        device
      end

      # @see ActionButton#action
      def action
        Actions::AddPartition.new(device)
      end
    end

    # Button for opening the workflow to add a logical volume to a volume group
    class LvmLvAddButton < DeviceAddButton
      # @macro seeAbstractWidget
      def label
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

    # Button for adding a new Btrfs subvolume
    class BtrfsSubvolumeAddButton < DeviceAddButton
      # @macro seeAbstractWidget
      def label
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
  end
end
