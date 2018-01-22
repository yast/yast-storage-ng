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
require "y2partitioner/actions/transaction_wizard"
require "y2partitioner/actions/controllers/lvm_vg"
require "y2partitioner/dialogs/lvm_vg_resize"

module Y2Partitioner
  module Actions
    # Action for resizing a new LVM volume group
    class ResizeLvmVg < TransactionWizard
      # Constructor
      #
      # @param lvm_vg [Y2Storage::LvmVg]
      def initialize(lvm_vg)
        super()

        @controller = Controllers::LvmVg.new(vg: lvm_vg)
      end

      # Runs the dialog for resizing the volume group
      #
      # @return [Symbol] :finish when the dialog successes
      def resize
        result = Dialogs::LvmVgResize.run(controller)
        result == :next ? :finish : result
      end

    protected

      # @return [Controllers::LvmVg]
      attr_reader :controller

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start" => "resize",
          "resize"   => { finish: :finish }
        }
      end
    end
  end
end
