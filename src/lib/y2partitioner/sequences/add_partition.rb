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
require "y2partitioner/sequences/new_blk_device"
require "y2partitioner/sequences/controllers"
require "y2partitioner/dialogs"

module Y2Partitioner
  module Sequences
    # formerly EpCreatePartition, DlgCreatePartition
    class AddPartition < TransactionWizard
      include NewBlkDevice

      # @param disk_name [String]
      def initialize(disk_name)
        textdomain "storage"

        super()
        @part_controller = Controllers::Partition.new(disk_name)
      end

      def preconditions
        return :next if part_controller.new_partition_possible?

        Yast::Popup.Error(
          # TRANSLATORS: %s is a device name (e.g. "/dev/sda")
          _("It is not possible to create a partition on %s.") % disk_name
        )
        :back
      end
      skip_stack :preconditions

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

      attr_reader :part_controller

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"      => "preconditions",
          "preconditions" => { next: "type" },
          "type"          => { next: "size" },
          "size"          => { next: new_blk_device_step1, finish: :finish }
        }.merge(new_blk_device_steps)
      end

      def disk_name
        part_controller.disk_name
      end
    end
  end
end
