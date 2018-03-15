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
require "y2partitioner/ui_state"
require "y2partitioner/actions/delete_device"

module Y2Partitioner
  module Actions
    # Action for deleting a disk device
    #
    # @see DeleteDevice
    class DeleteDiskDevice < DeleteDevice
      def initialize(*args)
        super
        textdomain "storage"
      end

    private

      # Deletes all partitions of a disk device (see {DeleteDevice#device})
      def delete
        log.info "deleting partitions from #{device}"
        device.partition_table.delete_all_partitions unless device.partition_table.nil?
        UIState.instance.select_row(device)
      end

      # @see DeleteDevice#errors
      def errors
        errors = super + [
          empty_partition_table_error,
          implicit_partition_table_error
        ]

        errors.compact
      end

      # Error when there is no partition for deleting
      #
      # @return [String, nil] nil if the partition table is not empty
      def empty_partition_table_error
        return nil unless device.partitions.empty?

        _("There are no partitions to delete on this disk")
      end

      # Error when the device contains an implicit partitition table
      #
      # @return [String, nil] nil if the device has no implicit partition table
      def implicit_partition_table_error
        return nil if !device.implicit_partition_table?

        _("This device cannot be deleted because an implicit partition table\n" \
          "must have one partition.")
      end

      # Confirmation before performing the delete action
      #
      # @note It shows all partitions (and dependent devices) that will be deleted.
      #
      # @see ConfirmRecursiveDelete#confirm_recursive_delete
      #
      # @return [Boolean]
      def confirm
        confirm_recursive_delete(
          device,
          _("Confirm Deleting of All Partitions"),
          # TRANSLATORS: name is the name of the disk to be deleted (e.g., /dev/sda)
          format(_("The disk \"%{name}\" contains at least one partition.\n" \
            "If you proceed, the following devices will be deleted:"), name: device.name),
          # TRANSLATORS: name is the name of the disk to be deleted (e.g., /dev/sda)
          format(_("Really delete all partitions on \"%{name}\"?"), name: device.name)
        )
      end
    end
  end
end
