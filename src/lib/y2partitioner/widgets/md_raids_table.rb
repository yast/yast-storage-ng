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
        add_columns(:raid_type, :chunk_size)
        remove_columns(:start, :end)
      end

    private

      def raid_type_title
        # TRANSLATORS: table header, type of md raid.
        _("RAID Type")
      end

      def chunk_size_title
        # TRANSLATORS: table header, chunk size of md raid
        _("Chunk Size")
      end

      # Content of the "RAID Type" cell in the table for the given device
      #
      # @param device [Y2Storage::Device]
      # @return [String]
      def raid_type_value(device)
        device.respond_to?(:md_level) ? device.md_level.to_human_string : ""
      end

      # Content of the "Chunk Size" cell in the table for the given device
      #
      # According to mdadm(8): chunk size "is only meaningful for RAID0, RAID4,
      # RAID5, RAID6, and RAID10".
      #
      # @param device [Y2Storage::Device]
      # @return [String]
      def chunk_size_value(device)
        return "" if !device.respond_to?(:chunk_size) || device.chunk_size.zero?
        device.chunk_size.to_human_string
      end
    end
  end
end
