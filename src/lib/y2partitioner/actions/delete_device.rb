# encoding: utf-8

# Copyright (c) [2017-2019] SUSE LLC
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
require "yast2/popup"
require "y2partitioner/device_graphs"
require "y2partitioner/confirm_recursive_delete"
require "y2partitioner/immediate_unmount"
require "y2partitioner/actions/base"
require "y2partitioner/actions/controllers/blk_device"
require "y2storage/filesystems/btrfs"
require "abstract_method"

module Y2Partitioner
  module Actions
    # Base class for the action to delete a device
    class DeleteDevice < Base
      include Yast::Logger
      include Yast::UIShortcuts
      include ConfirmRecursiveDelete
      include ImmediateUnmount

      # Constructor
      #
      # @param device [Y2Storage::Device]
      def initialize(device)
        super()

        textdomain "storage"

        @device = device
      end

    private

      # @return [Y2Storage::Device] device to delete
      attr_reader :device

      # Deletes the indicated device
      #
      # Derived classes should implement this method.
      abstract_method :delete

      # Checks whether delete action can be performed and if so, a confirmation popup is shown.
      # It only asks for unmounting the device it is currently mounted in the system.
      #
      # @see Actions::Base#run?
      #
      # @return [Boolean]
      def run?
        super && try_unmount && confirm
      end

      # Deletes the device and refreshes the shadowing BtrFS subvolumes
      #
      # @see Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing
      def perform_action
        delete
        Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(device_graph)
      end

      # Current devicegraph
      #
      # @return [Y2Storage::Devicegraph]
      def device_graph
        DeviceGraphs.instance.current
      end

      # Confirmation before performing the delete action
      #
      # @return [Boolean]
      def confirm
        if device.respond_to?(:partitions) && device.partitions.any?
          confirm_for_partitions
        elsif device.respond_to?(:component_of) && device.component_of.any?
          confirm_for_component
        else
          simple_confirm
        end
      end

      # Simple confirmation to display when only the device itself is affected
      #
      # @see #confirm
      #
      # @return [Boolean]
      def simple_confirm
        result = Yast2::Popup.show(simple_confirm_text, buttons: :yes_no)
        result == :yes
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
        format(_("Really delete %s and all the affected devices?"), device.name)
      end

      # Text to display in {#simple_confirm}
      #
      # @return [String]
      def simple_confirm_text
        # TRANSLATORS %s is the kernel name of the device (e.g., /dev/sda1)
        format(_("Really delete %s?"), device.name)
      end

      # Controller for a block device
      #
      # @return [Y2Partitioner::Actions::Controllers::BlkDevice, nil] nil when the device
      #   is not a block device.
      def controller
        return nil unless device.is?(:blk_device)

        @controller ||= Controllers::BlkDevice.new(device)
      end

      # Tries to unmount the device, if it is required.
      #
      # It asks the user for immediate unmount the device, see {#immediate_unmount}.
      #
      # @return [Boolean] true if it is not required to unmount or the device was correctly
      #   unmounted or the user decided to continue without unmounting; false when user cancels.
      def try_unmount
        return true unless need_try_unmount?

        # TRANSLATORS: Note added to the dialog for trying to unmount a device
        note = _("It cannot be deleted while mounted.")

        immediate_unmount(committed_device, note: note)
      end

      # Whether it is necessary to try unmount (i.e., when deleting a mounted block device that
      # exists on the system)
      #
      # @return [Boolean]
      def need_try_unmount?
        return false unless device.is?(:blk_device, :blk_filesystem)

        committed_device_mounted?
      end

      # Device taken from the system devicegraph
      #
      # @return [Y2Storage::Device, nil] nil if the device does not exist on disk yet.
      def committed_device
        controller.committed_device
      end

      # Whether {#committed_device} exists and is mounted, according to the
      # system devicegraph
      #
      # @return [Boolean]
      def committed_device_mounted?
        controller.mounted_committed_filesystem?
      end
    end
  end
end
