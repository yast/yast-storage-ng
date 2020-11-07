# Copyright (c) [2020] SUSE LLC
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

require "y2partitioner/widgets/action_button"
require "y2partitioner/widgets/device_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/actions/add_md"
require "y2partitioner/actions/edit_md_devices"
require "y2partitioner/actions/delete_md"

module Y2Partitioner
  module Widgets
    # Button for opening a wizard to add a new MD array
    class MdAddButton < ActionButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: button label to add a MD Raid
        _("Add RAID...")
      end

      # @see ActionButton#actions
      def action
        Actions::AddMd.new
      end
    end

    # Button for editing the used devices of a Software RAID
    class MdDevicesEditButton < DeviceButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: label for button to edit the used devices
        _("Change...")
      end

      # @see ActionButton#action
      def action
        Actions::EditMdDevices.new(device)
      end
    end

    # Button for deleting a MD RAID
    class MdDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteMd.new(device)
      end
    end
  end
end
