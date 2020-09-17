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

require "y2partitioner/dialogs/popup"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/columns"

module Y2Partitioner
  module Dialogs
    # Dialog to show the list of Bcache Caching Sets
    class BcacheCsets < Popup
      # Constructor
      def initialize
        textdomain "storage"
      end

      # Title of the dialog
      #
      # @return [String]
      def title
        _("Bcache Caching Sets")
      end

      # Contents of the dialog
      #
      # @return [Yast::Term]
      def contents
        @contents ||= VBox(BcacheCsetsTable.new)
      end

      private

      # @see Y2Partitioner::Dialogs::Popup
      def buttons
        [ok_button]
      end

      # @see Y2Partitioner::Dialogs::Popup
      def min_width
        77
      end

      # Table for caching set devices
      class BcacheCsetsTable < Widgets::BlkDevicesTable
        # Returns all caching set devices
        #
        # @see Widgets::BlkDevicesTable
        #
        # @return [Array<Y2Storage::BcacheCset>]
        def devices
          DeviceGraphs.instance.current.bcache_csets
        end

        # Columns to show
        #
        # @see Widgets::BlkDevicesTable
        #
        # @return [Array<Y2Partitioner::Widgets::Columns::Base>]
        def columns
          [
            Widgets::Columns::CachingDevice,
            Widgets::Columns::Size,
            Widgets::Columns::Uuid,
            Widgets::Columns::UsedBy
          ]
        end
      end
    end
  end
end
