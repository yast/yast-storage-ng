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
require "y2partitioner/ui_state"
require "y2partitioner/actions/transaction_wizard"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/controllers/btrfs_devices"
require "y2partitioner/dialogs/btrfs_devices"
require "y2partitioner/dialogs/btrfs_options"

module Y2Partitioner
  module Actions
    # Action for creating a new Btrfs filesystem (sigle or multidevice)
    class AddBtrfs < TransactionWizard
      # Constructor
      def initialize
        super

        textdomain "storage"
      end

      # Wizard step to select the devices used for creating the Btrfs
      #
      # The metadata and data RAID levels can be also selected.
      #
      # @see Dialogs::BtrfsDevices
      def devices
        Dialogs::BtrfsDevices.run(controller)
      end

      # Wizard step to select the filesystem options (mount point, subvolumes, snapshots, etc)
      #
      # @see Dialogs::BtrfsOptions
      def options
        fs_controller = Controllers::Filesystem.new(controller.filesystem, title)

        UIState.instance.select_row(controller.filesystem.sid)
        Dialogs::BtrfsOptions.run(fs_controller)
      end

      protected

      # @return Controllers::BtrfsDevices
      attr_reader :controller

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start" => "devices",
          "devices"  => { next: "options" },
          "options"  => { next: :finish }
        }
      end

      # @see TransactionWizard
      def init_transaction
        # The controller object must be created within the transaction
        @controller = Controllers::BtrfsDevices.new(wizard_title: title)
      end

      # Wizard title
      #
      # @return [String]
      def title
        # TRANSLATORS: wizard title when creating a new Btrfs filesystem.
        _("Add Btrfs")
      end

      # @see TransactionWizard
      def run?
        return true if controller.available_devices.any?

        # TRANSLATORS: error message
        error = _("There are not enough suitable unused devices to create a Btrfs.")

        Yast2::Popup.show(error, headline: :error)
        false
      end
    end
  end
end
