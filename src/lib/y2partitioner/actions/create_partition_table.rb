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
require "y2partitioner/actions/transaction_wizard"
require "y2partitioner/actions/controllers"
require "y2partitioner/dialogs"

module Y2Partitioner
  module Actions
    # Action for creating a new partition table
    class CreatePartitionTable < TransactionWizard
      attr_reader :controller

      # @param disk_name [String]
      def initialize(disk_name)
        textdomain "storage"

        super()
        @controller = Controllers::PartitionTable.new(disk_name)
      end

    protected

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"    => "select_type",
          "select_type" => { next: "confirm" },
          "confirm"     => { next: "commit" },
          "commit"      => { finish: :finish }
        }
      end

      # Open a dialog to let the user select the partition table type
      # if there is more than one to select from.
      def select_type
        return :next unless controller.multiple_types?
        Dialogs::PartitionTableType.run(controller)
      end

      # Ask the user for confirmation message before creating the partition
      # table.
      def confirm
        # TRANSLATORS %s is the name of the logical volume to be deleted
        msg = _("Really create a new partition table on %s?") % disk_name
        msg += "\n\n"
        msg += _("This will delete all existing partitions on that device\n" \
                 "and all devices (LVM volume groups, RAIDs etc.)\n" \
                 "that use any of those partitions!")
        Yast::Popup.YesNo(msg) ? :next : :abort
      end

      # Commit the action (creating a new partition table) to the staging
      # devicegraph. This does not open a dialog.
      def commit
        log.info("Commit creating a new #{controller.type} partition table on #{disk_name}")
        controller.create_partition_table
        :finish
      end

      # @see TransactionWizard
      def run?
        return true if controller.can_create_partition_table?

        Yast::Popup.Error(
          # TRANSLATORS: %s is a device name (e.g. "/dev/sda")
          _("It is not possible to create a new partition table on %s.") % disk_name
        )
        false
      end

      # Return the device name of the disk
      # @return [String]
      def disk_name
        controller.disk_name
      end
    end
  end
end
