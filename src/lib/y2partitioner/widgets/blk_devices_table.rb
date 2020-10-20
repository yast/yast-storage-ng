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
require "cwm/table"
require "y2partitioner/icons"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Abstract class to unify the definition of table widgets used to
    # represent collections of block devices.
    #
    # The subclasses must define the following methods:
    #
    #   * #columns returning an array of {Y2Partitioner::Widgets::Columns::Base}
    #   * #entries returning a collection of {DeviceTableEntry}
    #
    class BlkDevicesTable < CWM::Table
      include Help
      extend Yast::I18n

      textdomain "storage"

      # @see CWM::Table#header
      def header
        cols.map(&:title)
      end

      # @see CWM::Table#items
      def items
        entries.map { |e| e.table_item(cols) }
      end

      # Updates table content
      def refresh
        change_items(items)
      end

      # All devices referenced by the table entries
      #
      # @return [Array<Y2Storage::BlkDevice>]
      def devices
        entries.flat_map(&:all_devices)
      end

      protected

      # Entry of the table that references the given sid or device, if any
      #
      # @param device [Y2Storage::Device, Integer] sid or a device presenter
      # @return [DeviceTableEntry, nil]
      def entry(device)
        return nil if device.nil?

        sid = device.respond_to?(:sid) ? device.sid : device.to_i
        entries.flat_map(&:all_entries).find { |entry| entry.sid == sid }
      end

      private

      # @see #helptext_for
      def columns_help
        cols.map { |column| helptext_for(column.id) }.join("\n")
      end

      def cols
        @cols ||= columns.map(&:new)
      end
    end
  end
end
