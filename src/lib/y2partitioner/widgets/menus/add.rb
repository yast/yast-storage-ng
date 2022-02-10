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
require "y2partitioner/actions/add_md"
require "y2partitioner/actions/add_lvm_vg"
require "y2partitioner/actions/add_btrfs"
require "y2partitioner/actions/add_bcache"
require "y2partitioner/actions/add_partition"
require "y2partitioner/actions/add_lvm_lv"
require "y2partitioner/actions/add_btrfs_subvolume"
require "y2partitioner/actions/add_tmpfs"
require "y2partitioner/actions/add_nfs"

module Y2Partitioner
  module Widgets
    module Menus
      # Class to represent the Add menu
      class Add < Device
        # @see Device
        def initialize(*args)
          textdomain "storage"
          super
        end

        # @see Base
        def label
          # TRANSLATORS: Partitioner menu to create new devices
          _("&Add")
        end

        # @see Base
        def items
          @items ||= [
            Item(Id(:menu_add_md), _("&RAID...")),
            Item(Id(:menu_add_vg), _("LVM &Volume Group...")),
            Item(Id(:menu_add_btrfs), _("&Btrfs...")),
            Item(Id(:menu_add_bcache), _("B&cache...")),
            Item(Id(:menu_add_tmpfs), _("&Tmpfs...")),
            Item(Id(:menu_add_nfs), _("&NFS...")),
            Item("---"),
            Item(Id(:menu_add_partition), _("&Partition...")),
            Item(Id(:menu_add_lv), _("&Logical Volume...")),
            Item(Id(:menu_add_btrfs_subvolume), _("Btrfs &Subvolume..."))
          ]
        end

        private

        # @see Device
        def disabled_for_device
          items = []
          items << :menu_add_partition unless support_add_partition?
          items << :menu_add_lv unless support_add_lv?
          items << :menu_add_btrfs_subvolume unless support_add_btrfs_subvolume?
          items
        end

        # @see Device
        def disabled_without_device
          [:menu_add_partition, :menu_add_lv, :menu_add_btrfs_subvolume]
        end

        # @see Device#action_for
        def menu_add_md_action
          Actions::AddMd.new
        end

        # @see Device#action_for
        def menu_add_vg_action
          Actions::AddLvmVg.new
        end

        # @see Device#action_for
        def menu_add_btrfs_action
          Actions::AddBtrfs.new
        end

        # @see Device#action_for
        def menu_add_bcache_action
          Actions::AddBcache.new
        end

        # @see Device#action_for
        def menu_add_tmpfs_action
          Actions::AddTmpfs.new
        end

        # @see Device#action_for
        def menu_add_nfs_action
          Actions::AddNfs.new
        end

        # @see Device#action_for
        def menu_add_partition_action
          return unless support_add_partition?

          dev = device.is?(:partition) ? device.partitionable : device
          Actions::AddPartition.new(dev)
        end

        # @see Device#action_for
        def menu_add_lv_action
          return unless support_add_lv?

          vg = device.is?(:lvm_lv) ? device.lvm_vg : device
          Actions::AddLvmLv.new(vg)
        end

        # @see Device#action_for
        def menu_add_btrfs_subvolume_action
          return unless support_add_btrfs_subvolume?

          filesystem = device.is?(:btrfs) ? device : device.filesystem
          Actions::AddBtrfsSubvolume.new(filesystem)
        end

        # Whether the action to add a partition can be called with the current device
        #
        # @return [Boolean]
        def support_add_partition?
          return false unless device

          partitionable? || device.is?(:partition)
        end

        # Whether the action to add a LVM Logical Volume can be called with the current device
        def support_add_lv?
          return false unless device

          device.is?(:lvm_vg, :lvm_lv)
        end

        # Whether the action to add a Btrfs subvolume can be called with the current device
        #
        # @return [Boolean]
        def support_add_btrfs_subvolume?
          return false unless device

          return true if device.is?(:btrfs, :btrfs_subvolume)

          device.is?(:blk_device) && device.formatted_as?(:btrfs) && !device.filesystem.multidevice?
        end
      end
    end
  end
end
