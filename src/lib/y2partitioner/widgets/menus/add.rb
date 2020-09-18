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
require "y2partitioner/actions/add_partition"
require "y2partitioner/actions/add_md"

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
            Item(Id(:menu_add_raid), _("&RAID...")),
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
          disabled = []
          if !device.is?(:disk_device, :software_raid, :bcache, :partition)
            disabled << :menu_add_partition
          end
          disabled << :menu_add_lv unless device.is?(:lvm_vg, :lvm_lv)
          disabled
        end

        private

        # @see Base
        def action_for(event)
          case event
          when :menu_add_partition
            dev = device.is?(:partition) ? device.partitionable : device
            Actions::AddPartition.new(dev)
          when :menu_add_md
            Actions::AddMd.new
          end
        end
      end
    end
  end
end
