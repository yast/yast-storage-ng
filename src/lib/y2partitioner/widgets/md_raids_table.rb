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
    # Table widget to represent a given list of Y2Storage::Mds together.
    class MdRaidsTable < ConfigurableBlkDevicesTable
      # Constructor
      #
      # @param devices [Array<Y2Storage::Md>] devices to display
      # @param pager [CWM::Pager] table have feature, that double click change content of pager
      #   if someone do not need this feature, make it only optional
      def initialize(devices, pager, buttons_set = nil)
        textdomain "storage"

        super
        add_columns(Columns::RaidType, Columns::ChunkSize)
        remove_columns(Columns::RegionStart, Columns::RegionEnd)
      end
    end
  end
end
