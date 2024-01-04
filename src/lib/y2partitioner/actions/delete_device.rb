# Copyright (c) [2017-2021] SUSE LLC
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

require "yast2/popup"
require "y2partitioner/device_graphs"
require "y2partitioner/confirm_recursive_delete"
require "y2partitioner/recursive_unmount"
require "y2partitioner/actions/base"
require "abstract_method"

module Y2Partitioner
  module Actions
    # Base class for the action to delete a device
    class DeleteDevice < Base
      include ConfirmRecursiveDelete
      include RecursiveUnmount

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

      # Deletes the device
      #
      # Derived classes must implement this method.
      #
      # @see #perform_action
      abstract_method :delete

      # Checks whether the delete action can be performed. If so, a confirmation popup is shown.
      # It also asks for unmounting devices when any of the affected devices is currently mounted in the
      # system.
      #
      # @see Actions::Base#run?
      #
      # @return [Boolean]
      def run?
        super && confirm && unmount
      end

      # Deletes the device and refreshes the shadowing BtrFS subvolumes
      #
      # @see Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing
      def perform_action
        delete
        Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(device_graph)

        :finish
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

      # Confirmation to display when the device is part of another one(s)
      #
      # @see #confirm
      #
      # @return [Boolean]
      def confirm_for_component
        # FIXME: unify message for recursive deleting devices instead of having one specific message for
        #   each case.
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
        # FIXME: unify message for recursive deleting devices instead of having one specific message for
        #   each case.
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

      # Simple confirmation before performing the delete action
      #
      # @return [Boolean]
      def simple_confirm
        # TRANSLATORS %s is the name of the device (e.g., /dev/sda1)
        text = format(_("Really delete %s?"), device.display_name)

        Yast2::Popup.show(text, buttons: :yes_no) == :yes
      end

      # Asks for unmounting the affected devices, if required.
      #
      # @return [Boolean] see {#recursive_unmount}
      def unmount
        # TRANSLATORS: Note added to the dialog for trying to unmount a device
        note = _("Devices cannot be deleted while mounted.")

        recursive_unmount(device, note:)
      end

      # Current devicegraph
      #
      # @return [Y2Storage::Devicegraph]
      def device_graph
        DeviceGraphs.instance.current
      end
    end
  end
end
