# Copyright (c) [2020] SUSE LLC
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

require "y2partitioner/widgets/device_add_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/actions/add_partition"
require "y2partitioner/actions/delete_partition"

module Y2Partitioner
  module Widgets
    # Button for adding a partition to a block device
    class PartitionAddButton < DeviceAddButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: label for button to add a partition
        _("Add Partition...")
      end

      # When the selected device is a partition, its partitionable (disk, dasd, multipath or BIOS RAID)
      # is considered as the selected device.
      #
      # @see DeviceAddButton#device
      def device_or_parent(device)
        return device.partitionable if device.is?(:partition)

        device
      end

      # @see ActionButton#action
      def action
        Actions::AddPartition.new(device)
      end
    end

    # Button for deleting a partition
    class PartitionDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeletePartition.new(device)
      end
    end
  end
end
