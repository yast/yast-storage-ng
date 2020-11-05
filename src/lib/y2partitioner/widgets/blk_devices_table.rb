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

Yast.import "UI"

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
        @items ||= entries.map { |e| e.table_item(cols, open_items) }
      end

      # Hash listing the ids of the items with children of the table and specifying whether
      # such item should be expanded (true) or collapsed (false).
      #
      # @return [Hash{String => Boolean}]
      def open_items
        return default_open_items if !@open_items || @open_items.empty?

        @open_items
      end

      # Sets the value of {#open_items}
      #
      # @param value [Hash{String => Boolean}]
      def open_items=(value)
        # First, invalidate the items memoization
        @items = nil
        @open_items = value
      end

      # Current state of the open items in the user interface, regardless the
      # initial state specified by {#open_items}
      #
      # @return [Hash{String => Boolean}] same format as {#open_items}
      def ui_open_items
        open = Yast::UI.QueryWidget(Id(widget_id), :OpenItems).keys
        Hash[all_items.map { |i| [i.id, open.include?(i.id)] }]
      end

      # Updates table content
      def refresh
        @items = nil
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

      # Children limit to decide whether an entry is open/close by default
      OPEN_CHILDREN_LIMIT = 10
      private_constant :OPEN_CHILDREN_LIMIT

      # @see #helptext_for
      def columns_help
        cols.map { |column| helptext_for(column.id) }.join("\n")
      end

      def cols
        @cols ||= columns.map(&:new)
      end

      # Plain collection including the first level items and all its descendants
      #
      # @return [Array<CWM::TableItem>]
      def all_items
        items.flat_map { |item| item_with_descendants(item) }
      end

      # @see #all_items
      def item_with_descendants(item)
        [item] + item.children.flat_map { |child| item_with_descendants(child) }
      end

      # Items to be open by default
      #
      # Items with more than {OPEN_CHILDREN_LIMIT} children are closed by default.
      #
      # @see #open_items
      #
      # @return [Hash{String => Boolean}]
      def default_open_items
        all_entries = entries.flat_map(&:all_entries)

        all_entries.each_with_object({}) do |entry, result|
          result[entry.row_id] = (entry.children.size <= OPEN_CHILDREN_LIMIT)
        end
      end
    end
  end
end
