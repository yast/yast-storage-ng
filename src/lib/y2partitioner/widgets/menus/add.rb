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
require "y2partitioner/actions/add_md"
require "y2partitioner/actions/add_lvm_vg"
require "y2partitioner/actions/add_btrfs"
require "y2partitioner/actions/add_bcache"
require "y2partitioner/actions/add_partition"
require "y2partitioner/actions/add_lvm_lv"

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
            Item("---"),
            Item(Id(:menu_add_partition), _("&Partition...")),
            Item(Id(:menu_add_lv), _("&Logical Volume..."))
          ]
        end

        # @see Device
        def disabled_for_device
          items = []
          items << :menu_add_partition unless support_add_partition?
          items << :menu_add_lv unless support_add_lv?
          items
        end

        private

        # @see Base
        # rubocop:disable Metrics/CyclomaticComplexity
        # Is this a complex method actually?
        def action_for(event)
          case event
          when :menu_add_md
            Actions::AddMd.new
          when :menu_add_vg
            Actions::AddLvmVg.new
          when :menu_add_btrfs
            Actions::AddBtrfs.new
          when :menu_add_bcache
            Actions::AddBcache.new
          when :menu_add_partition
            add_partition_action
          when :menu_add_lv
            add_lv_action
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity

        # @see #action_for
        def add_partition_action
          return unless support_add_partition?

          dev = device.is?(:partition) ? device.partitionable : device
          Actions::AddPartition.new(dev)
        end

        # @see #action_for
        def add_lv_action
          return unless support_add_lv?

          vg = device.is?(:lvm_lv) ? device.lvm_vg : device
          Actions::AddLvmLv.new(vg)
        end

        # Whether the action to add a partition can be called with the current device
        #
        # @return [Boolean]
        def support_add_partition?
          partitionable? || device.is?(:partition)
        end

        # Whether the action to add a LVM Logical Volume can be called with the current device
        def support_add_lv?
          device.is?(:lvm_vg, :lvm_lv)
        end
      end
    end
  end
end
