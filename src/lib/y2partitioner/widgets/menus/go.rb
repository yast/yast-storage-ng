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
require "y2partitioner/actions/go_to_device_tab"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Widgets
    module Menus
      # Menu to go directly to some tabs of the current device
      class Go < Device
        extend Yast::I18n

        textdomain "storage"

        # @see Base
        def label
          _("&Go")
        end

        # @see Base
        def items
          @items ||= [
            Item(Id(:go_overview), "Device Overview"),
            Item(Id(:go_partitions), "Partitions"),
            Item(Id(:go_used_devices), "Used Devices"),
            Item(Id(:go_lvs), "Logical Volumes"),
            Item(Id(:go_pvs), "Physical Volumes")
          ]
        end

        private

        # @see Device
        def disabled_for_device
          disabled = []
          disabled << :go_used_devices unless device.is?(:software_raid, :btrfs)
          disabled << :go_pvs unless device.is?(:lvm_vg)
          disabled << :go_partitions unless device.is?(:software_raid, :disk_device, :bcache)
          disabled << :go_lvs unless device.is?(:lvm_vg)
          disabled
        end

        # @see Base
        def action_for(event)
          tab = target_tab(event)
          return nil unless tab

          pager = UIState.instance.overview_tree_pager
          Actions::GoToDeviceTab.new(device, pager, tab)
        end

        def target_tab(event)
          # FIXME: makes more sense as a hash
          case event
          when :go_overview
            _("&Overview")
          when :go_partitions
            _("&Partitions")
          when :go_lvs
            _("Log&ical Volumes")
          when :go_used_devices
            _("&Used Devices")
          when :go_pvs
            _("&Physical Volumes")
          end
        end
      end
    end
  end
end
