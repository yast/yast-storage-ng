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
require "y2partitioner/actions/transaction_wizard"
require "y2partitioner/actions/controllers/lvm_vg"
require "y2partitioner/dialogs/lvm_vg"

module Y2Partitioner
  module Actions
    # Action for creating a new LVM volume group
    class AddLvmVg < TransactionWizard
      def initialize(*args)
        super
        textdomain "storage"
      end

      # Runs the dialog for creating the volume group and applies
      # the given values to new created volume group.
      #
      # @see Controllers::LvmVg#apply_values
      #
      # @return [Symbol] :finish when the dialog successes
      def add_vg
        result = Dialogs::LvmVg.run(controller)
        return result if result != :next

        controller.apply_values
        :finish
      end

      protected

      # @return [Controllers::LvmVg]
      attr_reader :controller

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start" => "add_vg",
          "add_vg"   => { finish: :finish }
        }
      end

      # @see TransactionWizard
      # @note The controller object must be created within the transaction because
      #   a new volume group is created during initialization
      def init_transaction
        @controller = Controllers::LvmVg.new
      end

      # @see TransactionWizard
      # @note The action is only run when there are available devices to create a new
      #   volume group (see {Controllers::LvmVg#available_devices}).
      #
      # @return [Boolean] true whether there are available devices; false otherwise.
      def run?
        return true if controller.available_devices.size > 0

        Yast::Popup.Error(
          _("There are not enough suitable unused devices to create a volume group.\n") + "\n" +
          _("To use LVM, at least one unused partition of type 0x8e (or 0x83) or one disk\n" \
            "or one RAID device is required. Change your partition table accordingly.")
        )

        false
      end
    end
  end
end
