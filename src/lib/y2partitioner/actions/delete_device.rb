# Copyright (c) [2017-2020] SUSE LLC
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
require "y2partitioner/ui_state"
require "y2partitioner/device_graphs"
require "y2partitioner/confirm_recursive_delete"
require "y2partitioner/immediate_unmount"
require "y2partitioner/actions/base"
require "abstract_method"

module Y2Partitioner
  module Actions
    # Base class for the action to delete a device
    class DeleteDevice < Base
      include Yast::Logger
      include Yast::UIShortcuts
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

      # Deletes the device
      #
      # Derived classes must implement this method.
      #
      # @see #perform_action
      abstract_method :delete

      # Whether it is necessary to try to unmount (i.e., when deleting a mounted device that exists on
      # the system)
      #
      # Derived classes must implement this method.
      #
      # @see #try_unmount
      #
      # @return [Boolean]
      abstract_method :try_unmount?

      # Device taken from the system devicegraph
      #
      # Derived classes should implement this method, although this is only required when the device can
      # be mounted.
      #
      # @see #try_unmount
      #
      # @return [Y2Storage::Device, nil] nil if the device does not exist on disk yet.
      abstract_method :committed_device

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

        :finish
      end

      # Confirmation before performing the delete action
      #
      # @return [Boolean]
      def confirm
        # TRANSLATORS %s is the name of the device (e.g., /dev/sda1)
        text = format(_("Really delete %s?"), device.display_name)

        Yast2::Popup.show(text, buttons: :yes_no) == :yes
      end

      # Tries to unmount the device, if it is required.
      #
      # It asks the user for immediate unmount the device, see {#immediate_unmount}.
      #
      # @return [Boolean] true if it is not required to unmount or the device was correctly
      #   unmounted or the user decided to continue without unmounting; false when user cancels.
      def try_unmount
        return true unless try_unmount?

        # TRANSLATORS: Note added to the dialog for trying to unmount a device
        note = _("It cannot be deleted while mounted.")

        immediate_unmount(committed_device, note: note)
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
