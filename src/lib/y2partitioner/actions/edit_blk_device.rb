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
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/filesystem_steps"

Yast.import "Popup"

module Y2Partitioner
  module Actions
    # BlkDevice edition
    class EditBlkDevice < TransactionWizard
      include FilesystemSteps

      # @param blk_device [Y2Storage::BlkDevice]
      def initialize(blk_device)
        textdomain "storage"

        super()
        @device_sid = blk_device.sid
      end

    protected

      attr_reader :fs_controller

      # @see TransactionWizard
      def init_transaction
        # The controller object must be created within the transaction
        @fs_controller = Controllers::Filesystem.new(device, title)
      end

      # @see TransactionWizard
      def sequence_hash
        # If the device is unused from the editing point of view (very likely a
        # device just created by the Partitioner), it makes sense to offer the
        # role selection screen to setup some defaults.
        first_step = first_edit? ? "filesystem_role" : "format_options"

        { "ws_start" => first_step }.merge(filesystem_steps)
      end

      # Whether the device must be treated like a brand new one from this action
      # point of view.
      #
      # New devices in that regard are those that contain no file-system, no
      # encryption, etc., like devices just created by the previous Partitioner
      # action.
      #
      # @return [Boolean]
      def first_edit?
        desc_count = device.descendants.size
        return true if desc_count.zero?

        # If the only descendant is an empty partition table, then we can also
        # consider the device as "empty"
        desc_count == 1 && device.descendants.first.is?(:partition_table)
      end

      def title
        if device.is?(:md)
          # TRANSLATORS: dialog title. %s is a device name like /dev/md0
          _("Edit RAID %s") % device.name
        elsif device.is?(:lvm_lv)
          msg_args = { lv_name: device.lv_name, vg: device.lvm_vg.name }
          # TRANSLATORS: dialog title. %{lv_name} is an LVM LV name (e.g.'root'),
          # %{vg} is the device name of an LVM VG (e.g. '/dev/system').
          _("Edit Logical Volume %{lv_name} on %{vg}") % msg_args
        elsif device.is?(:partition)
          # TRANSLATORS: dialog title. %s is a device name like /dev/sda1
          _("Edit Partition %s") % device.name
        else
          # TRANSLATORS: dialog title. %s is a device name like /dev/sda
          _("Edit Device %s") % device.name
        end
      end

      # Extended partitions and LVM thin pools cannot be edited
      #
      # @note An error popup is shown when the edit action cannot be performed.
      #
      # @return [Boolean] true if the edit action can be performed; false otherwise.
      def run?
        return true if errors.empty?

        # Only first error is shown
        Yast::Popup.Error(errors.first)

        false
      end

      # Errors when trying to edit a device
      #
      # @return [Array<Strings>]
      def errors
        [used_device_error, partitions_error, btrfs_error,
         extended_partition_error, lvm_thin_pool_error].compact
      end

      # Error when trying to edit an used device
      #
      # @note A device is being used when it forms part of an LVM or MD RAID.
      #
      # @return [String, nil] nil if the device is not being used.
      def used_device_error
        using_devs = device.component_of_names
        return nil if using_devs.empty?

        format(
          # TRANSLATORS: %{name} is replaced by a device name (e.g., /dev/sda1)
          # and %{users} is replaced by a comma-separated list of name devices
          # (devices using the first one).
          _("The device %{name} is in use (%{users}).\n" \
            "It cannot be edited.\n" \
            "To edit %{name}, make sure it is not used."),
          name: device.name, users: using_devs.join(", ")
        )
      end

      # Error when trying to edit a device that is part of a multi-device Btrfs
      #
      # @return [String, nil] nil if the device is not part of a Btrfs
      def btrfs_error
        fs = device.filesystem
        return nil unless fs && fs.multidevice?

        format(
          # TRANSLATORS: %{name} is replaced by a device name (e.g., /dev/sda1).
          # Since device names can be rather long, make sure the lines
          # containing %{name} are sorter than the others.
          _("The device %{name} belongs to a Btrfs.\n" \
            "It cannot be edited.\n\n" \
            "To modify the settings of the Btrfs, edit the filesystem itself\n" \
            "instead of its individual block devices.\n\n" \
            "To use %{name} for other purpose, make sure it does not\n" \
            "belong to the Btrfs filesystem, either deleting the filesystem or\n" \
            "removing %{name} from it."),
          name: device.name
        )
      end

      # Error when trying to edit a device that contains partitions
      #
      # @return [String, nil] nil if the device has no partitions
      def partitions_error
        return nil unless device.respond_to?(:partitions) && !device.partitions.empty?

        format(
          # TRANSLATORS: %{name} is replaced by a device name (e.g., /dev/sda1).
          _("The device %{name} contains partitions.\n" \
            "It cannot be edited directly.\n" \
            "To edit %{name}, first delete all its partitions."),
          name: device.name
        )
      end

      # Error message if trying to edit an extended partition
      #
      # @return [String, nil] nil if the device is not an extended partition.
      def extended_partition_error
        return nil unless extended_partition?

        # TRANSLATORS: Error message when trying to edit an extented partition
        _("An extended partition cannot be edited")
      end

      # Error message is trying to edit an LVM thin pool
      #
      # @return [String, nil] nil if the device is not a thin pool.
      def lvm_thin_pool_error
        return nil unless lvm_thin_pool?

        # TRANSLATORS: Error message when trying to edit an LVM thin pool. %{name} is
        # replaced by a logical volume name (e.g., /dev/system/lv1)
        format(_("The volume %{name} is a thin pool.\nIt cannot be edited."), name: device.name)
      end

      # Whether the device is an extended partition
      #
      # @return [Boolean]
      def extended_partition?
        device.is?(:partition) && device.type.is?(:extended)
      end

      # Whether the device is an LVM thin pool
      #
      # @return [Boolean]
      def lvm_thin_pool?
        device.is?(:lvm_lv) && device.lv_type.is?(:thin_pool)
      end
    end
  end
end
