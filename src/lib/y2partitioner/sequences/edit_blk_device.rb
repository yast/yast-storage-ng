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
require "y2partitioner/sequences/transaction_wizard"
require "y2partitioner/sequences/controllers"
require "y2partitioner/dialogs"

Yast.import "Popup"

module Y2Partitioner
  module Sequences
    # BlkDevice edition
    class EditBlkDevice < TransactionWizard
      # @param blk_device [Y2Storage::BlkDevice]
      def initialize(blk_device)
        textdomain "storage"

        super()
        @blk_device = blk_device
        @fs_controller = Controllers::Filesystem.new(blk_device, title)
      end

      def preconditions
        if blk_device.is?(:partition) && blk_device.type.is?(:extended)
          Yast::Popup.Error(_("An extended partition cannot be edited"))
          :back
        else
          :next
        end
      end
      skip_stack :preconditions

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
          "ws_start"       => "preconditions",
          "preconditions"  => { next: "format_options" },
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
    end
  end
end
