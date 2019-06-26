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
require "yast/i18n"
require "yast2/popup"
require "y2partitioner/dialogs/partition_table_clone"
require "y2partitioner/actions/controllers/clone_partition_table"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Actions
    # Action for cloning a device
    #
    # To clone a device means to copy the partition table and its partitions. Filesystems,
    # encryptions, LVM or MD RAID over the partitions are not copied.
    class ClonePartitionTable
      include Yast::I18n

      # Constructor
      #
      # @param device [Y2Storage::Disk, Y2Storage::Dasd, Y2Storage::Multipath, Y2Storage::DmRaid]
      def initialize(device)
        textdomain "storage"

        @controller = Controllers::ClonePartitionTable.new(device)
      end

      # Checks whether it is possible to clone the device, and if so, the action is performed.
      #
      # @note An error popup is shown when the device cannot be cloned. In case the device
      #   can be cloned, a dialog is presented to select over which devices to clone. Selected
      #   devices are stored into the controller, see
      #   {Controllers::ClonePartitionTable#selected_devices_for_cloning}).
      #
      # @return [Symbol] :finish if the action is performed; :back or dialog result otherwise.
      def run
        return :back unless validate

        result = Dialogs::PartitionTableClone.run(controller)
        return result if result != :ok

        clone_partition_table
        UIState.instance.select_row(controller.device)
        :finish
      end

      private

      # @return [Controllers::ClonePartitionTable]
      attr_reader :controller

      # Checks whether the clone action can be performed
      #
      # @note A device can be cloned if it has a partition table and there are other
      #   suitable devices where to clone it. In case the device cannot be cloned, an
      #   error message is shown.
      #
      # @return [Boolean] true if the clone action can be performed; false otherwise.
      def validate
        error = partition_table_error || suitable_devices_error
        return true if error.nil?

        Yast2::Popup.show(error, headline: :error)

        false
      end

      # Error message when the device has no partition table
      #
      # @return [String, nil] nil if the device has partition table.
      def partition_table_error
        return nil if controller.partition_table?

        _("There are no partitions on this device, but a clonable\n" \
          "device must have at least one partition.\n" \
          "Create partitions before cloning the device.")
      end

      # Error message when there are no suitable devices where to clone the device
      #
      # @return [String, nil] nil if there are suitable devices.
      def suitable_devices_error
        return nil if controller.suitable_devices_for_cloning?

        _("This device cannot be cloned. There are no suitable\n" \
          "devices that could have the same partitioning layout.")
      end

      # Performs the cloning over the selected devices
      #
      # @see Controllers::ClonePartitionTable#clone_to_device
      def clone_partition_table
        controller.selected_devices_for_cloning.each { |d| controller.clone_to_device(d) }
      end
    end
  end
end
