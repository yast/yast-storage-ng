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
require "y2partitioner/actions/add_lvm_lv"
require "y2partitioner/actions/delete_lvm_lvs"

module Y2Partitioner
  module Widgets
    # Menu button for managing the logical volumes of an LVM volume group
    class LvmLogicalVolumesButton < DeviceMenuButton
      # Constructor
      def initialize(device, pager)
        textdomain "storage"
        super(device)
        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("&Logical Volumes")
      end

      private

      # @return [CWM::TreePager] general pager used to navigate through the
      #   partitioner
      attr_reader :pager

      # @see DeviceMenuButton#execute_action
      def execute_action(action)
        if action[:id] == :edit
          action[:class].new(device, pager, _("Log&ical Volumes")).run
        else
          super
        end
      end

      # @see DeviceMenuButton#actions
      #
      # @return [Array<Hash>]
      def actions
        [
          {
            id:    :edit,
            label: _("Edit Logical Volumes..."),
            class: Actions::GoToDeviceTab
          },
          {
            id:    :add,
            label: _("Add Logical Volume..."),
            class: Actions::AddLvmLv
          },
          {
            id:    :delete,
            label: _("Delete Logical Volumes..."),
            class: Actions::DeleteLvmLvs
          }
        ]
      end
    end
  end
end
