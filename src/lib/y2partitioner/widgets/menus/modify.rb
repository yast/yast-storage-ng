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

require "yast"
require "y2partitioner/widgets/menus/device"
require "y2partitioner/actions/delete_md"
require "y2partitioner/actions/delete_partition"
require "y2partitioner/actions/edit_md_devices"
require "y2partitioner/actions/edit_btrfs_devices"
require "y2partitioner/actions/edit_bcache"
require "y2partitioner/actions/resize_lvm_vg"

module Y2Partitioner
  module Widgets
    module Menus
      # Class to represent the Modify/Edit menu
      class Modify < Device
        # @see Base
        def label
          _("Device")
        end

        # @see Base
        def items
          @items ||= [
            Item(Id(:menu_edit), _("&Edit...")),
            Item(Id(:menu_delete), _("&Delete")),
            Item("---"),
            Item(Id(:menu_resize), _("&Resize...")),
            Item(Id(:menu_move), _("&Move...")),
            Item(Id(:menu_change_devs), "Change Used Devices..."),
            Item("---"),
            Item(Id(:menu_create_ptable), _("Create New Partition Table...")),
            Item(Id(:menu_clone_ptable), _("Clone Partitions to Another Device..."))
          ]
        end

        private

        # @see Device
        def disabled_for_device
          items = []
          items << :menu_edit if device.is?(:lvm_vg)
          items << :menu_resize unless device.is?(:partition, :lvm_lv)
          items << :menu_move unless device.is?(:partition)
          items << :menu_delete if device.is?(:disk_device)
          items << :menu_change_devs unless device.is?(:software_raid, :btrfs, :lvm_vg, :bcache)
          items << :menu_create_ptable unless device.is?(:software_raid, :disk_device, :bcache)
          items << :menu_clone_ptable unless device.is?(:disk_device)
          items
        end

        # @see Base
        def action_for(event)
          case event
          when :menu_delete
            if device.is?(:partition)
              Actions::DeletePartition.new(device)
            elsif device.is?(:md)
              Actions::DeleteMd.new(device)
            end
          when :menu_change_devs
            if device.is?(:software_raid)
              Actions::EditMdDevices.new(device)
            elsif device.is?(:lvm_vg)
              Actions::ResizeLvmVg.new(device)
            elsif device.is?(:btrfs)
              Actions::EditBtrfsDevices.new(device)
            else
              Actions::EditBcache.new(device)
            end
          end
        end
      end
    end
  end
end
