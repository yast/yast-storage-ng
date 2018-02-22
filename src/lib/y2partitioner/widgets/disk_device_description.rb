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

require "y2partitioner/widgets/blk_device_description"

module Y2Partitioner
  module Widgets
    # Richtext filled with the description of a disk device
    #
    # The disk device is given during initialization (see {BlkDeviceDescription}).
    class DiskDeviceDescription < BlkDeviceDescription
      def initialize(*args)
        super
        textdomain "storage"
      end

      # @see #blk_device_description
      # @see #disk_description
      #
      # @return [String]
      def device_description
        blk_device_description + disk_description
      end

      # Richtext description of a disk device
      #
      # A disk device description is composed by the header "Hard Disk" and
      # a list of attributes
      #
      # @return [String]
      def disk_description
        # TRANSLATORS: heading for section about a disk device
        output = Yast::HTML.Heading(_("Hard Disk:"))
        output << Yast::HTML.List(disk_attributes)
      end

      # Attributes for describing a disk device
      #
      # @return [Array<String>]
      def disk_attributes
        [
          device_vendor,
          device_model,
          device_bus,
          device_sectors,
          device_sector_size,
          device_label
        ]
      end

      # Fields to show in help
      #
      # @return [Array<Symbol>]
      def help_fields
        blk_device_help_fields + disk_help_fields
      end

      DISK_HELP_FIELDS = [:vendor, :model, :bus, :sectors, :sector_size, :disk_label].freeze

      # Help fields for a disk device
      #
      # @return [Array<Symbol>]
      def disk_help_fields
        DISK_HELP_FIELDS.dup
      end
    end
  end
end
