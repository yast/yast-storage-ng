# encoding: utf-8

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

require "y2partitioner/device_graphs"
require "y2partitioner/widgets/blk_devices_table"

module Y2Partitioner
  module Widgets
    # Table widget to represent a given list of devices in one of the
    # the main screens of the partitioner
    class ConfigurableBlkDevicesTable < BlkDevicesTable
      include Yast::I18n

      # Constructor
      #
      # @param devices [Array<Y2Storage::Device>]
      # @param pager [CWM::TreePager]
      def initialize(devices, pager)
        textdomain "storage"

        @devices = devices
        @pager = pager
      end

      def opt
        [:notify]
      end

      # @macro seeAbstractWidget
      def init
        initial_sid = UIState.instance.row_sid
        self.value = row_id(initial_sid) if initial_sid
      end

      # Jumps to the page associated to the selected device
      #
      # @note Event is launched after double clicking over a row.
      #
      # @macro seeAbstractWidget
      def handle
        device = selected_device
        return nil if device.nil?

        page = pager.device_page(device)
        return nil if page.nil?

        pager.handle("ID" => page.widget_id)
      end

      # Device object selected in the table
      #
      # @return [Y2Storage::Device, nil] nil if anything is selected
      def selected_device
        return nil if items.empty? || !value

        sid = value[/.*:(.*)/, 1].to_i
        device_graph.find_device(sid)
      end

      # Adds new columns to show in the table
      #
      # @note When a column :column_name is added, the methods #column_name_title
      #   and #column_name_value should exist.
      #
      # @param column_names [*Symbol]
      def add_columns(*column_names)
        columns.concat(column_names)
      end

      # Avoids to show some columns in the table
      #
      # @param column_names [*Symbol]
      def remove_columns(*column_names)
        column_names.each { |c| columns.delete(c) }
      end

      # Fixes a set of specific columns to show in the table
      #
      # @param column_names [*Symbol]
      def show_columns(*column_names)
        @columns = column_names
      end

      # @macro seeAbstractWidget
      # @see #columns_help
      def help
        header = _(
          "<p>This view shows storage devices.</p>" \
          "<p>The overview contains:</p>" \
        )

        header + columns_help
      end

    private

      attr_reader :pager
      attr_reader :devices

      DEFAULT_COLUMNS = [
        :device,
        :size,
        :format,
        :encrypted,
        :type,
        :filesystem_type,
        :filesystem_label,
        :mount_point,
        :start,
        :end
      ].freeze

      def device_graph
        DeviceGraphs.instance.current
      end

      def columns
        @columns ||= default_columns.dup
      end

      def default_columns
        DEFAULT_COLUMNS
      end
    end
  end
end
