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

require "y2partitioner/actions/delete_device"
require "y2partitioner/actions/controllers/blk_device"
require "y2partitioner/confirm_recursive_delete"

module Y2Partitioner
  module Actions
    # Base class for the action to delete a block device
    class DeleteBlkDevice < DeleteDevice
      include ConfirmRecursiveDelete

      def initialize(*args)
        super

        textdomain "storage"
      end

      private

      # Whether {#committed_device} exists and is mounted, according to the system devicegraph
      #
      # @see DeleteDevice#try_unmount?
      def try_unmount?
        controller.mounted_committed_filesystem?
      end

      # @see DeleteDevice#committed_device?
      def committed_device
        controller.committed_device
      end

      # Controller for a block device
      #
      # @return [Y2Partitioner::Actions::Controllers::BlkDevice]
      def controller
        @controller ||= Controllers::BlkDevice.new(device)
      end

      # Confirmation before performing the delete action
      #
      # @see DeleteDevice#confirm
      #
      # @return [Boolean]
      def confirm
        if device.respond_to?(:partitions) && device.partitions.any?
          confirm_for_partitions
        elsif device.respond_to?(:component_of) && device.component_of.any?
          confirm_for_component
        else
          super
        end
      end

      # Confirmation to display when the device is part of another one(s)
      #
      # @see #confirm
      #
      # @return [Boolean]
      def confirm_for_component
        confirm_recursive_delete(
          device,
          _("Confirm Deleting of Devices"),
          _("The selected device is used by other devices in the system.\n" \
            "To keep the system in a consistent state, the following devices\n" \
            "will also be deleted:"),
          recursive_confirm_text_below
        )
      end

      # Confirmation to display when the device contains partitions
      #
      # @see #confirm
      #
      # @return [Boolean]
      def confirm_for_partitions
        confirm_recursive_delete(
          device,
          _("Confirm Deleting Device with Partitions"),
          _("The selected device contains partitions.\n" \
            "To keep the system in a consistent state, the following partitions\n" \
            "and its associated devices will also be deleted:"),
          recursive_confirm_text_below
        )
      end

      # Text to display as final question, below the list of devices, when
      # {#confirm_recursive_delete} is called
      #
      # @see #confirm_for_partitions
      # @see #confirm_for_component
      #
      # @return [String]
      def recursive_confirm_text_below
        # TRANSLATORS %s is a kernel name like /dev/sda1
        format(_("Really delete %s and all the affected devices?"), device.display_name)
      end
    end
  end
end
