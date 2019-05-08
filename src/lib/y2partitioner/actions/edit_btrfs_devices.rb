# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/actions/transaction_wizard"
require "y2partitioner/actions/controllers/btrfs_devices"
require "y2partitioner/dialogs/btrfs_devices"
require "y2partitioner/device_graphs"

Yast.import "Popup"

module Y2Partitioner
  module Actions
    # Action for editing the devices of a Btrfs filesystem
    class EditBtrfsDevices < TransactionWizard
      # Constructor
      #
      # @param filesystem [Y2Storage::Filesystems::Btrfs]
      def initialize(filesystem)
        super()
        textdomain "storage"

        @device_sid = filesystem.sid
      end

      # Calls the dialog for editing the devices (and metadata/data RAID levels)
      #
      # @return [Symbol]
      def devices
        Dialogs::BtrfsDevices.run(controller)
      end

    private

      # @return [Controllers::BtrfsDevices]
      attr_reader :controller

      alias_method :filesystem, :device

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start" => "devices",
          "devices"  => { next: :finish }
        }
      end

      # @see TransactionWizard
      def init_transaction
        # The controller object must be created within the transaction
        @controller = Controllers::BtrfsDevices.new(filesystem: filesystem, wizard_title: title)
      end

      # Wizard title
      #
      # @return [String]
      def title
        format(_("Edit devices of Btrfs %{name}"), name: filesystem.blk_device_basename)
      end

      # Whether it is possible to edit the used devices
      #
      # An error popup is shown when the filesystem already exists on disk.
      #
      # @see TransactionWizard
      #
      # @return [Boolean]
      def run?
        current_errors = errors

        return true if current_errors.none?

        message = current_errors.join("\n\n")

        Yast2::Popup.show(message, headline: :error)
        false
      end

      # Errors that avoid to edit the devices
      #
      # @return [Array<String>]
      def errors
        [committed_error].compact
      end

      # Error the filesystem exists on disk
      #
      # @return [String, nil] nil if the filesystem does not exist on disk yet.
      def committed_error
        return nil unless committed?

        # TRANSLATORS: error message, where %{name} is replaced by a device base name (e.g., sda1)
        format(
          _("The Btrfs %{name} is already created on disk and its used devices\n" \
            "cannot be modified. To modify the used devices, remove the Btrfs\n" \
            "and create it again."),
          name: filesystem.blk_device_basename
        )
      end

      # Whether the filesystem is already created on disk
      #
      # @return [Boolean]
      def committed?
        filesystem.exists_in_devicegraph?(system_graph)
      end

      # Devicegraph representing the system status
      #
      # @return [Y2Storage::Devicegraph]
      def system_graph
        Y2Partitioner::DeviceGraphs.instance.system
      end
    end
  end
end
