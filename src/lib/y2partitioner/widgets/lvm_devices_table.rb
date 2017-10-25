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
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/lvm_lv_attributes"

module Y2Partitioner
  module Widgets
    # Table widget to represent a given list of LVM devices.
    class LvmDevicesTable < ConfigurableBlkDevicesTable
      include LvmLvAttributes

      # Constructor
      #
      # @param devices [Array<Y2Storage::Lvm_vg, Y2Storage::Lvm_lv>] devices to display
      # @param pager [CWM::Pager] table have feature, that double click change content of pager
      #   if someone do not need this feature, make it only optional
      def initialize(devices, pager)
        textdomain "storage"

        super
        add_columns(:pe_size, :stripes)
        remove_columns(:start, :end)
      end

    private

      def pe_size_title
        # TRANSLATORS: table header, type of metadata
        _("PE Size")
      end

      def stripes_title
        # TRANSLATORS: table header, number of LVM LV stripes
        _("Stripes")
      end

      def pe_size_value(device)
        return "" unless device.respond_to?(:extent_size)
        device.extent_size.to_human_string
      end

      def stripes_value(device)
        return "" unless devices.respond_to?(:stripes)
        stripes_info(device)
      end
    end
  end
end
