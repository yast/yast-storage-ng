# Copyright (c) [2020-2022] SUSE LLC
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
require "y2partitioner/widgets/menus/device"
require "y2partitioner/actions/delete_partition"
require "y2partitioner/actions/delete_md"
require "y2partitioner/actions/delete_lvm_vg"
require "y2partitioner/actions/delete_lvm_lv"
require "y2partitioner/actions/delete_bcache"
require "y2partitioner/actions/delete_btrfs"
require "y2partitioner/actions/delete_btrfs_subvolume"
require "y2partitioner/actions/delete_tmpfs"
require "y2partitioner/actions/edit_md_devices"
require "y2partitioner/actions/edit_btrfs_devices"
require "y2partitioner/actions/edit_bcache"
require "y2partitioner/actions/resize_lvm_vg"
require "y2partitioner/actions/edit_blk_device"
require "y2partitioner/actions/edit_btrfs"
require "y2partitioner/actions/edit_btrfs_subvolume"
require "y2partitioner/actions/edit_tmpfs"
require "y2partitioner/actions/resize_blk_device"
require "y2partitioner/actions/move_partition"
require "y2partitioner/actions/create_partition_table"
require "y2partitioner/actions/clone_partition_table"
require "y2partitioner/dialogs/device_description"

module Y2Partitioner
  module Widgets
    module Menus
      # Class to represent the Modify/Edit menu
      class Modify < Device
        # @see Device
        def initialize(*args)
          textdomain "storage"
          super
        end

        # @see Base
        def label
          # TRANSLATORS: Partitioner menu with actions to perform on the
          # currently selected device
          _("&Device")
        end

        # @see Base
        def items
          @items ||= [
            Item(Id(:menu_edit), _("&Edit...")),
            Item(Id(:menu_description), _("&Show Details")),
            Item(Id(:menu_delete), _("&Delete")),
            Item("---"),
            Item(Id(:menu_resize), _("&Resize...")),
            Item(Id(:menu_move), _("&Move...")),
            Item(Id(:menu_change_devs), _("Change &Used Devices...")),
            Item("---"),
            Item(Id(:menu_create_ptable), _("Create New &Partition Table...")),
            Item(Id(:menu_clone_ptable), _("&Clone Partitions to Another Device..."))
          ]
        end

        private

        # @see Device
        def disabled_for_device
          items = disabled_for_type
          items << :menu_resize unless device.is?(:partition, :lvm_lv)
          items << :menu_move unless device.is?(:partition)
          items << :menu_change_devs unless multidevice?
          items << :menu_create_ptable unless partitionable?
          items << :menu_clone_ptable unless device.is?(:disk_device)
          items
        end

        # @see Device
        def action_for(*args)
          return nil unless device

          super
        end

        # @see Device#action_for
        def menu_edit_action
          if device.is?(:blk_device) && device.usable_as_blk_device?
            Actions::EditBlkDevice.new(device)
          elsif device.is?(:btrfs)
            Actions::EditBtrfs.new(device)
          elsif device.is?(:btrfs_subvolume)
            Actions::EditBtrfsSubvolume.new(device)
          elsif device.is?(:tmpfs)
            Actions::EditTmpfs.new(device)
          end
        end

        # @see Device#action_for
        def menu_delete_action
          return if device.is?(:disk_device)

          device_class = device.class.name.split("::").last
          action_class = "Y2Partitioner::Actions::Delete#{device_class}"

          return unless Kernel.const_defined?(action_class)

          Kernel.const_get(action_class).new(device)
        end

        # @see Device#action_for
        def menu_resize_action
          Actions::ResizeBlkDevice.new(device) if device.is?(:partition, :lvm_lv)
        end

        # @see Device#action_for
        def menu_move_action
          Actions::MovePartition.new(device) if device.is?(:partition)
        end

        # @see Device#action_for
        def menu_change_devs_action
          if device.is?(:software_raid)
            Actions::EditMdDevices.new(device)
          elsif device.is?(:lvm_vg)
            Actions::ResizeLvmVg.new(device)
          elsif device.is?(:btrfs)
            Actions::EditBtrfsDevices.new(device)
          elsif device.is?(:bcache)
            Actions::EditBcache.new(device)
          end
        end

        # @see Device#action_for
        def menu_create_ptable_action
          Actions::CreatePartitionTable.new(device) if partitionable?
        end

        # @see Device#action_for
        def menu_clone_ptable_action
          Actions::ClonePartitionTable.new(device) if device.is?(:disk_device)
        end

        # @see Base
        def dialog_for(event)
          return nil unless event == :menu_description
          return nil unless device

          Dialogs::DeviceDescription.new(device)
        end

        # @see @disabled_for_device
        def disabled_for_type
          if device.is?(:disk_device, :stray_blk_device)
            [:menu_delete]
          elsif device.is?(:lvm_vg)
            [:menu_edit]
          else
            []
          end
        end
      end
    end
  end
end
