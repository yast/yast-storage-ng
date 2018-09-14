# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/widgets/device_button"
require "y2partitioner/actions/clone_partition_table"

module Y2Partitioner
  module Widgets
    # Button for cloning the partition table
    class PartitionTableCloneButton < DeviceButton
      def initialize(*args)
        super
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: label for button to clone a partition table
        _("Clone Partitions...")
      end

    private

      # Returns the proper Actions class for cloning a partition table
      #
      # @see DeviceButton#actions
      # @see Actions::ClonePartitionTable
      def actions_class
        Actions::ClonePartitionTable
      end
    end
  end
end
