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
    class DeleteDisk < DeleteDevice
      # Checks whether there is any partition for deleting
      #
      # @note An error popup is shown when there is no partition.
      #
      # @return [Boolean]
      def validate
        textdomain "storage"

        partition_table = device.partition_table
        if partition_table.nil? || partition_table.partitions.empty?
          Yast::Popup.Error(_("There are no partitions to delete on this disk"))
          return false
        end

        true
      end

      # Confirmation message before performing the delete action
      #
      # It shows all partitions (and dependent devices) that will be deleted.
      #
      # @see DeleteDevice#dependent_devices
      # @see DeleteDevice#confirm_recursive_delete
      def confirm
        confirm_recursive_delete(
          dependent_devices,
          _("Confirm Deleting of All Partitions"),
          # TRANSLATORS: name is the name of the disk to be deleted (e.g., /dev/sda)
          format(_("The disk \"%{name}\" contains at least one partition.\n" \
            "If you proceed, the following devices will be deleted:"), name: device.name),
          # TRANSLATORS: name is the name of the disk to be deleted (e.g., /dev/sda)
          format(_("Really delete all partitions on \"%{name}\"?"), name: device.name)
        )
      end

      # Deletes all partitions of a disk device (see {DeleteDevice#device})
      def delete
        log.info "deleting partitions for #{device}"
        device.partition_table.delete_all_partitions unless device.partition_table.nil?
        UIState.instance.select_row(device)
      end
    end
  end
end
