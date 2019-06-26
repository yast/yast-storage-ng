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
require "y2partitioner/widgets/device_menu_button"
require "y2partitioner/actions/go_to_device_tab"
require "y2partitioner/actions/add_partition"
require "y2partitioner/actions/delete_partitions"
require "y2partitioner/actions/clone_partition_table"

module Y2Partitioner
  module Widgets
    # Menu button for managing the (potential) partitions in a device
    class PartitionsButton < DeviceMenuButton
      def initialize(device, pager)
        textdomain "storage"
        super(device)
        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("&Partitions")
      end

      private

      # @return [CWM::TreePager] general pager used to navigate through the
      #   partitioner
      attr_reader :pager

      # @see DeviceMenuButton#execute_action
      def execute_action(action)
        if action[:id] == :edit
          action[:class].new(device, pager, _("&Partitions")).run
        else
          super
        end
      end

      # @see DeviceMenuButton#actions
      #
      # @return [Array<Hash>]
      def actions
        return @actions if @actions

        @actions = [
          {
            id:    :edit,
            label: _("Edit Partitions..."),
            class: Actions::GoToDeviceTab
          },
          {
            id:    :add,
            label: _("Add Partition..."),
            class: Actions::AddPartition
          },
          {
            id:    :delete,
            label: _("Delete Partitions..."),
            class: Actions::DeletePartitions
          }
        ]
        if device.is?(:disk_device)
          @actions << {
            id:    :clone,
            label: _("Clone Partitions to Other Devices..."),
            class: Actions::ClonePartitionTable
          }
        end

        @actions
      end
    end
  end
end
