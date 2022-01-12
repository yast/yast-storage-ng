# Copyright (c) [2017-2021] SUSE LLC
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
        @open_items || default_open_items
      end

      # Sets the value of {#open_items}
      #
      # @param value [Hash{String => Boolean}]
      def open_items=(value)
        # First, invalidate the items memoization
        @items = nil
        @open_items = add_missing_items(value)
      end

      # Current state of the open items in the user interface, regardless the initial state specified by
      # {#open_items}
      #
      # Note that items without children are considered as open. This is useful to automatically open the
      # edited item, for example, when Btrfs subvolumes are automatically added.
      #
      # @return [Hash{String => Boolean}] same format as {#open_items}
      def ui_open_items
        open = Yast::UI.QueryWidget(Id(widget_id), :OpenItems).keys
        all_items.map { |i| [i.id, open.include?(i.id) || i.children.none?] }.to_h
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

      # Adds the missing items to the given collection of open items
      #
      # This is useful to automatically open/close items that were created after saving the page state.
      #
      # @param items [Hash{String => Boolean}]
      def add_missing_items(items)
        return nil unless items

        default_open_items.merge(items)
      end

      # Items to be open by default
      #
      # @see #open_items
      #
      # @return [Hash{String => Boolean}]
      def default_open_items
        all_entries.each_with_object({}) do |entry, result|
          result[entry.row_id] = open_by_default?(entry)
        end
      end

      # Whether the given table entry should be expanded by default
      #
      # @see #default_open_items
      #
      # @param _entry [DeviceTableEntry]
      # @return [Boolean] false if the list of entry children should be collapsed
      def open_by_default?(_entry)
        true
      end

      # Plain collection including the first level entries and all its descendants
      #
      # @return [Array<DeviceTableEntry>]
      def all_entries
        entries.flat_map(&:all_entries)
      end
    end
  end
end
