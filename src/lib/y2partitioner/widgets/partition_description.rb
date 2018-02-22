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
    # Richtext filled with the description of a partition
    #
    # The partition is given during initialization (see {BlkDeviceDescription}).
    class PartitionDescription < BlkDeviceDescription
      def initialize(*args)
        super
        textdomain "storage"
      end

      # Attributes for describing a partition
      #
      # @note Same description than a general block device, but including information
      #   about the partition id.
      #
      # @return [Array<String>]
      def blk_device_attributes
        super << partition_id
      end

      # Information about the partition id
      #
      # @return [String]
      def partition_id
        # TRANSLATORS: Partition Identifier, where %s is replaced by the partition id (e.g., SWAP)
        format(_("Partition ID: %s"), device.id.to_human_string)
      end

      # Help fields for a partition
      #
      # @note Same fields than a general block device, but including the partition id.
      #
      # @return [Array<Symbol>]
      def blk_device_help_fields
        super << :partition_id
      end
    end
  end
end
