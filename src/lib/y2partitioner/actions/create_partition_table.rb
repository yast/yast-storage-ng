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
require "y2partitioner/device_graphs"
require "y2partitioner/dialogs/partition_table_type"
require "y2partitioner/confirm_recursive_delete"

Yast.import "Label"

module Y2Partitioner
  module Actions
    # Action for creating a new partition table
    class CreatePartitionTable
      include Yast::I18n
      include Yast::Logger
      include ConfirmRecursiveDelete

      # @param disk [Y2Storage::Partitionable]
      def initialize(disk)
        textdomain "storage"
        @disk = disk
      end

      # Checks whether the action can be performed, displays a confirmation
      # popup and, if everything goes fine so far, performs the action.
      #
      # @return [Symbol]
      def run
        return :back unless validate && confirm

        perform_action
        :finish
      end

    protected

      # @return [Y2Storage::Partitionable]
      attr_reader :disk

      # Device name of the partitionable device
      # @return [String]
      def disk_name
        disk.name
      end

      # Creates the new partition table, asking the user for the type if needed
      #
      # Does nothing if the user cancels the action when asked for the type
      def perform_action
        type = possible_types.size > 1 ? selected_type : default_type
        return if type.nil?

        create_partition_table(type)
      end

      # Creates the new partition table
      #
      # @param type [Y2Storage::PartitionTables::Type]
      def create_partition_table(type)
        disk.remove_descendants
        ptable = disk.create_partition_table(type)
        if ptable.type.is?(:msdos)
          ptable.minimal_mbr_gap = Y2Storage::DiskSize.B(512)
        end
        Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(device_graph)
      end

      # Checks if a partition table can be created on the disk, displaying an
      # informative popup if it's not possible.
      #
      # @return [Boolean]
      def validate
        return true if possible_types.size > 0

        Yast::Popup.Error(
          # TRANSLATORS: %s is a device name (e.g. "/dev/sda")
          _("It is not possible to create a new partition table on %s.") % disk_name
        )
        false
      end

      # If the operation have destructive consequences, ask for confirmation
      # to the user.
      #
      # @return [Boolean] true if the action is safe or the user confirmed
      #   to accept the consequences
      def confirm
        return true if safe?

        if disk.filesystem
          confirm_with_filesystem
        else
          confirm_with_nested_devices
        end
      end

      # Whether performing the action can be considered non-destructive, from
      # the point of view of this action
      #
      # Destroying an unused partition table or an unused encryption layer is
      # considered to be non-destructive in that regard.
      #
      # @return [Boolean] true if the disk (that may be encrypted) is completely
      #   empty and unused or if it only contains an empty partition table
      def safe?
        desc = disk.descendants.size
        return true if desc.zero?
        return false if desc > 1

        disk.partition_table? || disk.encrypted?
      end

      # @see #confirm
      def confirm_with_nested_devices
        confirm_recursive_delete(
          disk,
          _("Confirm Deleting of Current Devices"),
          _("If you proceed, the following devices will be deleted:"),
          # TRANSLATORS %s is the disk device name ("/dev/sda" or similar)
          _("Really create a new partition table on %s") % disk_name
        )
      end

      # @see ConfirmRecursiveDelete#recursive_delete_yes_label
      def recursive_delete_yes_label
        Yast::Label.YesButton
      end

      # @see ConfirmRecursiveDelete#recursive_delete_no_label
      def recursive_delete_no_label
        Yast::Label.NoButton
      end

      # @see #confirm
      def confirm_with_filesystem
        fs = disk.filesystem.type.to_human
        # TRANSLATORS: the first %s is replaced by the type of the filesystem
        # (for example, "Btrfs" or "Ext2"), the second one by the disk device name
        # ("/dev/sda" or similar).
        msg = format(
          _(
            "This will delete all data from the %s file system in the device.\n\n" \
            "Really create a new partition table on %s?"
          ),
          fs, disk_name
        )
        result = Yast2::Popup.show(msg, buttons: :yes_no)
        result == :yes
      end

      def selected_type
        dialog = Dialogs::PartitionTableType.new(disk, possible_types, default_type)

        return nil unless dialog.run == :next
        dialog.selected_type
      end

      # Partition table types that are supported by this disk
      #
      # @return [Array<Y2Storage::PartitionTables::Type>]
      def possible_types
        @possible_types ||= disk.possible_partition_table_types
      end

      # Return the default partition table types for this disk.
      def default_type
        @default_type ||= disk.preferred_ptable_type || possible_types.first
      end

      # Current devicegraph
      #
      # @return [Y2Storage::Devicegraph]
      def device_graph
        DeviceGraphs.instance.current
      end
    end
  end
end
