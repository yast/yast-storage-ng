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
    #   * #devices returning a collection of {Y2Storage::BlkDevice}
    #
    class BlkDevicesTable < CWM::Table
      include Help
      extend Yast::I18n

      textdomain "storage"

      # Helper class to create a row with children
      class DeviceTree
        attr_accessor :device
        attr_accessor :children

        def initialize(device, children: [])
          @device = device
          @children = children
        end

        def sid
          device.sid
        end

        def to_list
          list = [device] + children.map { |c| c.is_a?(DeviceTree) ? c.to_list : c }

          list.flatten
        end
      end

      # @see CWM::Table#header
      def header
        cols.map(&:title)
      end

      # @see CWM::Table#items
      def items
        devices.map { |d| row_for(d) }
      end

      # Updates table content
      def refresh
        change_items(items)
      end

      private

      # Returns true if given sid or device is available in table
      # @param device [Y2Storage::DevicePresenter, Integer] sid or a device presenter
      def valid_sid?(device)
        return false if device.nil?

        sid = device.respond_to?(:sid) ? device.sid : device.to_i

        flat_devices.any? { |d| d.sid == sid }
      end

      def flat_devices
        devices.map { |d| d.respond_to?(:to_list) ? d.to_list : d }.flatten
      end

      # @see #helptext_for
      def columns_help
        cols.map { |column| helptext_for(column.id) }.join("\n")
      end

      def row_for(device)
        if device.is_a?(DeviceTree)
          tree = device
          device = device.device
        else
          tree = DeviceTree.new(device)
        end

        values = cols.map { |c| c.value_for(device) }
        children = tree.children.map { |c| row_for(c) }

        item(row_id(device), values, children: children)
      end

      # LibYUI id to use for the row used to represent a device
      #
      # @param device [Y2Storage::Device, Integer] sid or device object
      #
      # @return [String] row id for given device
      def row_id(device)
        sid = device.respond_to?(:sid) ? device.sid : device.to_i

        "table:device:#{sid}"
      end

      def cols
        @cols ||= columns.map(&:new)
      end
    end
  end
end
