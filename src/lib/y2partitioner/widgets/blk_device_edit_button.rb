# Copyright (c) [2017-2020] SUSE LLC
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
require "y2partitioner/widgets/device_button"
require "y2partitioner/actions/edit_blk_device"

module Y2Partitioner
  module Widgets
    # Device button for modifying a {Y2Storage::BlkDevice}
    class BlkDeviceEditButton < DeviceButton
      def initialize(*args)
        super
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        _("&Edit...")
      end

      private

      # Returns the proper Actions class for editing a device
      #
      # @see DeviceButton#actions
      # @see Actions::EditBlkDevice
      def actions_class
        Actions::EditBlkDevice
      end
    end
  end
end
