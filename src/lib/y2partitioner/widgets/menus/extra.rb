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

module Y2Partitioner
  module Widgets
    module Menus
      # Menu with extra actions for a device (beyond those included in Edit/Modify)
      class Extra < Device
        # Constructor
        def initialize(*args)
          textdomain "storage"

          super
        end

        # @see Base
        def label
          _("Actions")
        end

        # @see Base
        def items
          @items ||= [
            Item(Id(:menu_change_devs), "Change Used Devices..."),
            Item(Id(:menu_change_pvs), "Change Physical Volumes..."),
            Item(Id(:menu_change_cache), "Change Caching..."),
            Item("---"),
            Item(Id(:menu_create_ptable), _("Create New Partition Table...")),
            Item(Id(:menu_clone_ptable), _("Clone Partitions to Another Device..."))
          ]
        end

        private

        # @see Device
        def disabled_for_device
          items = []
          items << :menu_change_devs unless device.is?(:software_raid, :btrfs, :lvm_vg)
          items << :menu_change_pvs unless device.is?(:lvm_vg)
          items << :menu_change_cache unless device.is?(:bcache)
          items << :menu_create_ptable unless device.is?(:software_raid, :disk_device, :bcache)
          items << :menu_clone_ptable unless device.is?(:disk_device)
          items
        end
      end
    end
  end
end
