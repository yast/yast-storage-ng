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
require "y2partitioner/actions/new_blk_device"
require "y2partitioner/actions/controllers"
require "y2partitioner/dialogs"

module Y2Partitioner
  module Actions
    # formerly EpCreatePartition, DlgCreatePartition
    class AddPartition < TransactionWizard
      include NewBlkDevice

      # @param disk [Y2Storage::BlkDevice]
      def initialize(disk)
        textdomain "storage"

        super()
        @device_sid = disk.sid
      end

      # Removes the filesystem when the device is directly formatted
      def delete_filesystem
        part_controller.delete_filesystem if part_controller.disk_formatted?
        :next
      end

      def type
        Dialogs::PartitionType.run(part_controller)
      end

      def size
        part_controller.delete_partition
        result = Dialogs::PartitionSize.run(part_controller)
        part_controller.create_partition if [:next, :finish].include?(result)
        if result == :next
          part = part_controller.partition
          title = part_controller.wizard_title
          self.fs_controller = Controllers::Filesystem.new(part, title)
        end
        result
      end

    protected

      # @return [Controllers::Partition]
      attr_reader :part_controller

      # @see TransactionWizard
      def init_transaction
        # The controller object must be created within the transaction
        @part_controller = Controllers::Partition.new(device.name)
      end

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"          => "delete_filesystem",
          "delete_filesystem" => { next: "type" },
          "type"              => { next: "size" },
          "size"              => { next: new_blk_device_step1, finish: :finish }
        }.merge(new_blk_device_steps)
      end

      skip_stack :delete_filesystem

      def disk_name
        part_controller.disk_name
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
        if part_controller.disk.respond_to?(:partitions)
          true
        else
          impossible_partition_popup
          false
        end
      end

      # Checks whether the device is not used
      #
      # @see Controllers::Partition#disk_used?
      #
      # @return [Boolean] true if device is not used; false otherwise.
      def not_used_validation
        return true unless part_controller.disk_used?

        Yast::Popup.Error(
          _("The disk is in use and cannot be modified.")
        )

        false
      end

      # Checks whether the device is not formatted
      #
      # @see Controllers::Partition#disk_formatted?
      #
      # @note A confirm popup to delete the filesystem is shown when the device
      #   is directly formatted.
      #
      # @return [Boolean] true if device is not formatted or confirm popup is
      #   accepted; false otherwise.
      def not_formatted_validation
        return true unless part_controller.disk_formatted?

        Yast::Popup.YesNo(
          # TRANSLATORS: %{name} is a device name (e.g. "/dev/sda")
          format(
            _("The device %{name} is directly formatted.\n"\
              "Remove the filesystem on %{name}?"),
            name: disk_name
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
        return true if part_controller.disk_formatted?
        return true if part_controller.new_partition_possible?

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
            name: disk_name
          )
        )
      end
    end
  end
end
