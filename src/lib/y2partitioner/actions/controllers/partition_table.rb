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
require "y2storage"
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about a future partition table so that
      # information can be shared across the different dialogs of the
      # process. It also takes care of updating the devicegraph when needed.
      class PartitionTable
        include Yast::I18n
        include Yast::Logger

        # Partition table type to be used. If not set, the default type for
        # this type of disk is used: one of Gpt, Msdos, Dasd.
        #
        # @return [Y2Storage::PartitionTables::Type]
        attr_accessor :type

        # New partition table created by the controller.
        #
        # @return [Y2Storage::PartitionTables::Any]
        attr_reader :partition_table

        # Name of the device being partitioned.
        # @return [String]
        attr_reader :disk_name

        # @param [String] disk_name
        def initialize(disk_name)
          textdomain "storage"

          @disk_name = disk_name
          log.error("Can't find disk #{@disk_name}") if disk.nil?
          @type = possible_partition_table_types.first
        end

        # The disk (or similar device) we are working on
        # @return [Y2Storage::Partitionable]
        def disk
          DeviceGraphs.instance.current.find_by_name(disk_name)
        end

        # Create the disk partition table in the devicegraph.
        def create_partition_table
          return if type.nil? || disk.nil?

          disk.remove_descendants
          disk.create_partition_table(type)
          UIState.instance.select_row(disk)
        end

        # Return the partition table types that are supported by this disk.
        def possible_partition_table_types
          return [] if disk.nil?
          disk.possible_partition_table_types
        end

        # Check if a partition table can be created on this disk.
        def can_create_partition_table?
          possible_partition_table_types.size > 0
        end

        # Check if multiple types of partition table are possible on this disk.
        def multiple_types?
          possible_partition_table_types.size > 1
        end

        # Title to display in the dialogs during the process
        # @return [String]
        def wizard_title
          # TRANSLATORS: dialog title. %s is a device name like /dev/sda
          _("Create New Partition Table on %s") % disk_name
        end
      end
    end
  end
end
