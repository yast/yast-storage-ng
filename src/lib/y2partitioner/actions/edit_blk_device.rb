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

Yast.import "Popup"

module Y2Partitioner
  module Actions
    # BlkDevice edition
    class EditBlkDevice < TransactionWizard
      # @param blk_device [Y2Storage::BlkDevice]
      def initialize(blk_device)
        textdomain "storage"

        super()
        @blk_device = blk_device
        @fs_controller = Controllers::Filesystem.new(blk_device, title)
      end

      def format_options
        Dialogs::FormatAndMount.run(fs_controller)
      end

      def password
        return :next unless fs_controller.to_be_encrypted?
        Dialogs::EncryptPassword.run(fs_controller)
      end

      def commit
        fs_controller.finish
        :finish
      end

    protected

      attr_reader :fs_controller, :blk_device

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"       => "format_options",
          "format_options" => { next: "password" },
          "password"       => { next: "commit" },
          "commit"         => { finish: :finish }
        }
      end

      def title
        if blk_device.is?(:md)
          # TRANSLATORS: dialog title. %s is a device name like /dev/md0
          _("Edit RAID %s") % blk_device.name
        elsif blk_device.is?(:lvm_lv)
          msg_args = { lv_name: blk_device.lv_name, vg: blk_device.lvm_vg.name }
          # TRANSLATORS: dialog title. %{lv_name} is an LVM LV name (e.g.'root'),
          # %{vg} is the device name of an LVM VG (e.g. '/dev/system').
          _("Edit Logical Volume %{lv_name} on %{vg}") % msg_args
        else
          # TRANSLATORS: dialog title. %s is a device name like /dev/sda1
          _("Edit Partition %s") % blk_device.name
        end
      end

      # Extended partitions and LVM thin pools cannot be edited
      #
      # @note An error popup is shown when the edit action cannot be performed.
      #
      # @return [Boolean] true if the edit action can be performed; false otherwise.
      def run?
        error = extended_partition_error || lvm_thin_pool_error
        return true unless error

        Yast::Popup.Error(error)
        false
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
        format(_("The volume %{name} is a thin pool.\nIt cannot be edited."), name: blk_device.name)
      end

      # Whether the device is an extended partition
      #
      # @return [Boolean]
      def extended_partition?
        blk_device.is?(:partition) && blk_device.type.is?(:extended)
      end

      # Whether the device is an LVM thin pool
      #
      # @return [Boolean]
      def lvm_thin_pool?
        blk_device.is?(:lvm_lv) && blk_device.lv_type.is?(:thin_pool)
      end
    end
  end
end
