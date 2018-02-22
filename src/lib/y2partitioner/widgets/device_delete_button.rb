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
require "y2partitioner/widgets/device_button"
require "y2partitioner/actions/delete_disk"
require "y2partitioner/actions/delete_partition"
require "y2partitioner/actions/delete_lvm_vg"
require "y2partitioner/actions/delete_lvm_lv"
require "y2partitioner/actions/delete_md"

module Y2Partitioner
  module Widgets
    # Button for deleting a device
    class DeviceDeleteButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: label for button to delete a device
        _("Delete...")
      end

    private

      # Returns the proper Actions class to perform the delete action
      #
      # @see Actions::DeleteDevice
      # @see Actions::DeleteDisk
      # @see Actions::DeletePartition
      # @see Actions::DeleteLvmVg
      # @see Actions::DeleteLvmLv
      # @see Actions::DeleteMd
      #
      # @return [Actions::DeleteDevice]
      def actions_class
        if device.is?(:disk)
          Actions::DeleteDisk
        elsif device.is?(:partition)
          Actions::DeletePartition
        elsif device.is?(:lvm_vg)
          Actions::DeleteLvmVg
        elsif device.is?(:lvm_lv)
          Actions::DeleteLvmLv
        elsif device.is?(:md)
          Actions::DeleteMd
        end
      end
    end
  end
end
