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
require "y2partitioner/actions/create_partition_table"

module Y2Partitioner
  module Widgets
    # "Expert" menu
    class DiskExpertMenuButton < CWM::MenuButton
      include Yast::Logger

      def initialize(disk: nil)
        @disk = disk
        self.handle_all_events = true
      end

      def label
        # Translators: Expert menu for disks in the partitioner.
        _("&Expert...")
      end

      # Menu items
      #
      # @return [Array<[Symbol, String]>]
      def items
        [[:create_partition_table, _("Create New Partition &Table...")]]
      end

      # Event handler for the expert menu
      #
      # @param event [Hash] UI event
      # @return [:redraw, nil] :redraw when the action is performed;
      #   nil otherwise.
      def handle(event)
        id = event["ID"]
        result = case id
        when :create_partition_table
          create_partition_table
        end

        result == :finish ? :redraw : nil
      end

    private

      def create_partition_table
        log.info("User selected 'create new partition table' for #{@disk.name}")
        Actions::CreatePartitionTable.new(@disk.name).run
      end
    end
  end
end
