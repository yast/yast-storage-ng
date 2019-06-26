# Copyright (c) [2018-2019] SUSE LLC
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
require "y2partitioner/actions/edit_md_devices"
require "y2partitioner/actions/edit_btrfs_devices"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Button for editing the used devices (e.g., by a Software RAID)
    class UsedDevicesEditButton < DeviceButton
      def initialize(*args)
        super
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: label for button to edit used devices
        _("Change...")
      end

      private

      # Returns the proper Actions class to edit the used devices
      #
      # @see DeviceButton#actions
      # @see Actions::EditMdDevices
      # @see Actions::EditBtrfsDevices
      def actions_class
        if device.is?(:software_raid)
          Actions::EditMdDevices
        elsif device.is?(:btrfs)
          Actions::EditBtrfsDevices
        end
      end
    end
  end
end
