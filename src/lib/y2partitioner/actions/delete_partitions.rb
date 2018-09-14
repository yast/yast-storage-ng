# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
    # Action for deleting all partitions (without deleting the partition table).
    #
    # @see DeleteDevice
    class DeletePartitions < DeleteDevice
      def initialize(*args)
        super

        textdomain "storage"
      end

    private

      # Deletes all partitions (see {DeleteDevice#device})
      def delete
        log.info "deleting partitions from #{device}"

        device.partitions.each { |p| device.partition_table.delete_partition(p) }
        UIState.instance.select_row(device)
      end

      # @see DeleteDevice#errors
      def errors
        errors = super + [
          formatted_device_error,
          missing_partition_table_error,
          empty_partition_table_error
        ]

        errors.compact
      end

      # Error when the device is directly formatted
      #
      # @return [String, nil] nil if the device is not directly formatted.
      def formatted_device_error
        return nil unless device.formatted?

        format(
          # TRANSLATORS: Error when trying to delete partitions from a directly formatted
          # device. %{name} is replaced by the name of the device (e.g. "/dev/sda").
          _("The device %{name} is directly formatted and\n"\
            "and it does not contain any partition."),
          name: device.name
        )
      end

      # Error when the device has no partition table
      #
      # @return [String, nil] nil if the device has a partition table
      def missing_partition_table_error
        return nil if device.partition_table?

        # TRANSLATORS: Error when trying to delete partitions from a device that does not contain
        # a partition table. %{name} is replaced by the name of the device (e.g. "/dev/sda").
        format(_("The device %{name} does not contain a partition table."), name: device.name)
      end

      # Error when the device has a partition table with no partitions
      #
      # @return [String, nil] nil if there is any partition
      def empty_partition_table_error
        return nil if device.partitions.any?

        # TRANSLATORS: Error when trying to delete partitions from a device with an empty
        # partition table.
        _("The partition table does not contain partitions.")
      end

      # @see DeleteDevices#confirm
      #
      # @return [Boolean]
      def confirm
        confirm_recursive_delete(
          device,
          _("Confirm Deleting of Current Devices"),
          _("If you proceed, the following devices will be deleted:"),
          _("Really delete all these devices?")
        )
      end
    end
  end
end
