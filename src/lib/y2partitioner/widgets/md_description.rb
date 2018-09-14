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
    # Richtext filled with the description of a MD RAID
    #
    # The MD RAID is given during initialization (see {BlkDeviceDescription}).
    class MdDescription < BlkDeviceDescription
      def initialize(*args)
        super
        textdomain "storage"
      end

      # @see #blk_device_description
      # @see #raid_description
      # @see #filesystem_description
      #
      # @return [String]
      def device_description
        blk_device_description + raid_description + filesystem_description
      end

      # Richtext description of a MD RAID
      #
      # A MD RAID description is composed by the header "RAID" and a list of attributes.
      #
      # @return [String]
      def raid_description
        # TRANSLATORS: heading for section about RAID details
        output = Yast::HTML.Heading(_("RAID:"))
        output << Yast::HTML.List(raid_attributes)
      end

      # Attributes for describing a MD RAID
      #
      # @return [Array<String>]
      def raid_attributes
        [
          raid_active,
          raid_type,
          raid_chunk_size,
          raid_parity,
          device_label
        ]
      end

      # Information about MD RAID being (in)active
      #
      # @return [String]
      def raid_active
        # TRANSLATORS: RAID being active (assembled), where %s is replaced by
        # 'Yes' when the device is active or by 'No' otherwise
        format(_("Active: %s"), blk_device.active? ? _("Yes") : _("No"))
      end

      # Information about MD RAID type
      #
      # @return [String]
      def raid_type
        # TRANSLATORS: RAID type information, where %s is replaced by a
        # raid type (e.g., RAID0)
        format(_("RAID Type: %s"), device.md_level.to_human_string)
      end

      # Information about the MD RAID chunk size according to mdadm(8):
      # chunk size "is only meaningful for RAID0, RAID4, RAID5, RAID6, and RAID10"
      #
      # @return [String]
      def raid_chunk_size
        # TRANSLATORS: chunk size information of the MD RAID, where %s is replaced by
        # a size (e.g., 8 KiB)
        chunk_size = device.chunk_size
        format(_("Chunk Size: %s"), chunk_size.zero? ? "" : chunk_size.to_human_string)
      end

      # Information about the MD RAID parity algorithm
      #
      # @return [String]
      def raid_parity
        # TRANSLATORS: parity algorithm information of a MD RAID, where %s is replaced by
        # the name of the parity strategy
        format(_("Partity algorithm: %s"), device.md_parity.to_human_string)
      end

      # Fields to show in help
      #
      # @return [Array<Symbol>]
      def help_fields
        blk_device_help_fields + raid_help_fields + filesystem_help_fields
      end

      RAID_HELP_FIELDS = [:raid_type, :chunk_size, :parity_algorithm, :disk_label].freeze

      # Help fields for a MD RAID
      #
      # @return [Array<Symbol>]
      def raid_help_fields
        RAID_HELP_FIELDS.dup
      end
    end
  end
end
