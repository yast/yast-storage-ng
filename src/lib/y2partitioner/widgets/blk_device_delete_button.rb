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
require "y2partitioner/widgets/blk_device_button"
require "y2partitioner/actions/delete_blk_device"

module Y2Partitioner
  module Widgets
    # Button for deleting a disk device or partition
    class BlkDeviceDeleteButton < BlkDeviceButton
      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to delete a disk device or partition
        _("Delete...")
      end

      # Performs delete action
      #
      # @see Actions::DeleteBlkDevice#run
      #
      # @return [:redraw, nil] {:redraw} when the action is performed; {nil} otherwise
      def actions
        res = Actions::DeleteBlkDevice.new(device).run
        res == :finish ? :redraw : nil
      end
    end
  end
end