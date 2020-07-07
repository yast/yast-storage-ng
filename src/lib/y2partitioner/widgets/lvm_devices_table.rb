# Copyright (c) [2017] SUSE LLC
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
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/columns"

module Y2Partitioner
  module Widgets
    # Table widget to represent a given list of LVM devices.
    class LvmDevicesTable < ConfigurableBlkDevicesTable
      # Constructor
      #
      # @param devices [Array<Y2Storage::Lvm_vg, Y2Storage::Lvm_lv>] see {#devices}
      # @param pager [CWM::Pager] see {#pager}
      # @param buttons_set [DeviceButtonsSet] see {#buttons_set}
      def initialize(devices, pager, buttons_set = nil)
        textdomain "storage"

        super
        add_columns(Columns::PeSize, Columns::Stripes)
        remove_columns(Columns::RegionStart, Columns::RegionEnd)
      end
    end
  end
end
