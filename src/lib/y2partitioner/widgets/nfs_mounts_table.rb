# Copyright (c) [2022] SUSE LLC
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
    # Table for NFS mounts
    class NfsMountsTable < ConfigurableBlkDevicesTable
      # Constructor
      #
      # @param entries [Array<DeviceTableEntry>]
      # @param pager [CWM::Pager]
      # @param buttons_set [DeviceButtonsSet, nil]
      def initialize(entries, pager, buttons_set = nil)
        textdomain "storage"

        super
        show_columns(*fs_columns)
      end

      private

      # Table columns
      #
      # @return [Array<#new>]
      def fs_columns
        [
          Columns::NfsServer,
          Columns::NfsPath,
          Columns::MountPoint,
          Columns::NfsVersion,
          Columns::MountOptions
        ]
      end
    end
  end
end
