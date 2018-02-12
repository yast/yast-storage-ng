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
    # Wizard to add a new LVM logical volume
    class AddLvmLv < TransactionWizard
      include NewBlkDevice

      # @param vg [Y2Storage::LvmVg]
      def initialize(vg)
        super()

        @device_sid = vg.sid
      end

      # Wizard step to indicate properties for a new logical volume (i.e., the name and type)
      #
      # @note Given values are stored into the controller. The values for size and stripes
      # are reset because that values depend on the selection in this step.
      #
      # @see Controllers::LvmLv
      # @see Dialogs::LvmLvInfo.run
      def name_and_type
        result = Dialogs::LvmLvInfo.run(controller)
        controller.reset_size_and_stripes if result == :next
        result
      end

      # Wizard step to indicate the size and stripes data (number and size)
      # for the new logical volume.
      #
      # @note Given values are stored into the controller and then a new
      #   logical volume is created with those values. When a previous logical
      #   volume exists (e.g, when going back in the wizard), that volume is
      #   deleted before creating a new one. Also note that this is the last
      #   wizard step when the new volume is a thin pool.
      #
      # @see Controllers::LvmLv
      # @see Dialogs::LvmLvSize.run
      def size
        controller.delete_lv

        result = Dialogs::LvmLvSize.run(controller)
        return result if result != :next

        controller.create_lv
        return :finish unless controller.lv_can_be_formatted?

        self.fs_controller = Controllers::Filesystem.new(controller.lv, controller.wizard_title)
        result
      end

    protected

      # @return [Controllers::LvmLv]
      attr_reader :controller

      # @see TransactionWizard
      def init_transaction
        # The controller object must be created within the transaction
        @controller = Controllers::LvmLv.new(device)
      end

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start"      => "name_and_type",
          "name_and_type" => { next: "size" },
          "size"          => { next: new_blk_device_step1, finish: :finish }
        }.merge(new_blk_device_steps)
      end

      # Name of the volume group
      #
      # @return [String]
      def vg_name
        controller.vg_name
      end

      # @see TransactionWizard
      def run?
        return true if lv_can_be_added?

        Yast::Popup.Error(
          # TRANSLATORS: %s is a volume group name (e.g. "system")
          _("No free space left in the volume group \"%s\".") % vg_name
        )
        false
      end

      # Whether a new logical volume can be added (thin or not)
      #
      # @return [Boolean]
      def lv_can_be_added?
        controller.lv_can_be_added? || controller.thin_lv_can_be_added?
      end
    end
  end
end
