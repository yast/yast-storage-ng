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
require "y2partitioner/widgets/device_edit_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/actions/add_bcache"
require "y2partitioner/actions/edit_bcache"
require "y2partitioner/actions/delete_bcache"

module Y2Partitioner
  module Widgets
    # Button for opening a wizard to add a new Bcache device
    class BcacheAddButton < ActionButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: button label to add a new Bcache device
        _("Add Bcache...")
      end

      # @see ActionButton#action
      def action
        Actions::AddBcache.new
      end
    end

    # Button for editing a Bcache
    class BcacheEditButton < DeviceEditButton
      # @macro seeAbstractWidget
      def label
        textdomain "storage"

        # TRANSLATORS: label for the button to edit a Bcache
        _("Change Caching...")
      end

      # @see ActionButton#action
      def action
        Actions::EditBcache.new(device)
      end
    end

    # Button for deleting a Bcache
    class BcacheDeleteButton < DeviceDeleteButton
      # @see ActionButton#action
      def action
        Actions::DeleteBcache.new(device)
      end
    end
  end
end
