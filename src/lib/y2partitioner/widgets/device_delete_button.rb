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
require "y2partitioner/actions/delete_bcache"
require "y2partitioner/actions/delete_partition"
require "y2partitioner/actions/delete_lvm_vg"
require "y2partitioner/actions/delete_lvm_lv"
require "y2partitioner/actions/delete_md"
require "y2partitioner/actions/delete_btrfs"

module Y2Partitioner
  module Widgets
    # Button for deleting a device
    class DeviceDeleteButton < DeviceButton
      def initialize(*args)
        super
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: label for button to delete a device
        _("Delete")
      end

      private

      DEVICE_MAPPING = {
        partition: Actions::DeletePartition,
        lvm_vg:    Actions::DeleteLvmVg,
        lvm_lv:    Actions::DeleteLvmLv,
        md:        Actions::DeleteMd,
        bcache:    Actions::DeleteBcache,
        btrfs:     Actions::DeleteBtrfs
      }
      private_constant :DEVICE_MAPPING

      # Returns the proper Actions class to perform the delete action
      #
      # @see Actions::DeleteBcache
      # @see Actions::DeleteDevice
      # @see Actions::DeletePartition
      # @see Actions::DeleteLvmVg
      # @see Actions::DeleteLvmLv
      # @see Actions::DeleteMd
      # @see Actions::DeleteBtrfs
      #
      # @return [Actions::DeleteDevice,nil] returns nil if action is not yet implemented
      def actions_class
        DEVICE_MAPPING.each_pair do |type, result|
          return result if device.is?(type)
        end

        nil
      end
    end
  end
end
