# Copyright (c) [2022] SUSE LLC
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

require "yast2/popup"
require "y2partitioner/actions/delete_device"

module Y2Partitioner
  module Actions
    # Action for deleting an NFS mount
    #
    # @see DeleteDevice
    class DeleteNfs < DeleteDevice
      # Constructor
      def initialize(*args)
        textdomain "storage"

        super
      end

      private

      # Deletes the indicated filesystem (see {DeleteDevice#device})
      def delete
        device_graph.remove_nfs(device)
      end

      # @see DeleteDevice#confirm
      def confirm
        # TRANSLATORS: Confirmation to delete an NFS mount, %s is replaced by
        # something like 'server:/path'
        text = _("Really delete %s?") % device.name
        Yast2::Popup.show(text, buttons: :yes_no) == :yes
      end
    end
  end
end
