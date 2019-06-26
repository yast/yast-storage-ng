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
require "y2partitioner/actions/controllers/add_partition"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/filesystem_steps"
require "y2partitioner/dialogs/partition_type"
require "y2partitioner/dialogs/partition_size"

module Y2Partitioner
  module Actions
    # formerly EpCreatePartition, DlgCreatePartition
    class AddPartition < TransactionWizard
      include FilesystemSteps

      # @param device [Y2Storage::BlkDevice]
      def initialize(device)
        textdomain "storage"

        super()
        @device_sid = device.sid
      end

      # Removes the filesystem when the device is directly formatted
      def delete_filesystem
        controller.delete_filesystem if controller.device_formatted?
        :next
      end

      def type
        case available_types.size
        when 0
          raise "No partition type possible"
        when 1
          controller.type = available_types.first
          :next
        else
          # Only run the dialog if more than one partition type is available
          # (bsc#1075443)
          Dialogs::PartitionType.run(controller)
        end
      end

      def size
        controller.delete_partition
        result = Dialogs::PartitionSize.run(controller)
        controller.create_partition if [:next, :finish].include?(result)
        if result == :next
          part = controller.partition
          title = controller.wizard_title
          self.fs_controller = Controllers::Filesystem.new(part, title)
        end
        result
      end

      protected

      # @return [Controllers::Partition]
      attr_reader :controller

      # @see TransactionWizard
      def init_transaction
        # The controller object must be created within the transaction
        @controller = Controllers::AddPartition.new(device.name)

        # Once the controller is created we know which steps can be skipped
        # when going back
        skip_steps
      end

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"          => "delete_filesystem",
          "delete_filesystem" => { next: "type" },
          "type"              => { next: "size" },
          "size"              => { next: first_filesystem_step, finish: :finish }
        }.merge(filesystem_steps)
      end

      def device_name
        controller.device_name
      end

      # @see TransactionWizard
      # @note In case the device is formatted, the wizard is started
      #   only if the user confirms to delete the current filesystem.
      #
      # @return [Boolean]
      def run?
        partitionable_validation && not_used_validation &&
          not_formatted_validation && available_space_validation
      end

      # Checks whether the device can contain partitions, which is not true
      # for StrayBlkDevice objects (they are listed as disks but they are not).
      #
      # @return [Boolean] true if device can be partitioned, false otherwise
      def partitionable_validation
        if controller.device.respond_to?(:partitions)
          true
        else
          impossible_partition_popup
          false
        end
      end

      # Checks whether the device is not used
      #
      # @see Controllers::Partition#device_used?
      #
      # @return [Boolean] true if device is not used; false otherwise.
      def not_used_validation
        return true unless controller.device_used?

        Yast::Popup.Error(
          _("The device is in use and cannot be modified.")
        )

        false
      end

      # Checks whether the device is not formatted
      #
      # @see Controllers::Partition#device_formatted?
      #
      # @note A confirm popup to delete the filesystem is shown when the device
      #   is directly formatted.
      #
      # @return [Boolean] true if device is not formatted or confirm popup is
      #   accepted; false otherwise.
      def not_formatted_validation
        return true unless controller.device_formatted?

        Yast::Popup.YesNo(
          # TRANSLATORS: %{name} is a device name (e.g. "/dev/sda")
          format(
            _("The device %{name} is directly formatted.\n"\
              "Remove the filesystem on %{name}?"),
            name: device_name
          )
        )
      end

      # Checks whether it is possible to create a new partition.
      #
      # @see Controllers::Partition#new_partition_possible?
      #
      # @note When the device is formatted, it is consisered that there is enough
      #   space for a new partition due to the filesystem could be deleted.
      #
      # @return [Boolean]
      def available_space_validation
        return true if controller.device_formatted?
        return true if controller.new_partition_possible?

        impossible_partition_popup
        false
      end

      # Displays a popup telling the user it's not possible to create a
      # partition
      def impossible_partition_popup
        Yast::Popup.Error(
          format(
            # TRANSLATORS: %{name} is a device name (e.g. "/dev/sda")
            _("It is not possible to create a partition on %{name}."),
            name: device_name
          )
        )
      end

      # Convenience method for returning the device available partition types
      #
      # @return [Array<Y2Storage::PartitionType>]
      def available_types
        controller.available_partition_types
      end

      # Convenience method for setting the steps that have to be skipped when
      # going back
      def skip_steps
        self.class.skip_stack :delete_filesystem
        self.class.skip_stack :type if available_types.size < 2
      end
    end
  end
end
