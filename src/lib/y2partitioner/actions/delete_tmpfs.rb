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

require "yast2/popup"
require "y2partitioner/actions/delete_device"

module Y2Partitioner
  module Actions
    # Action for deleting a Tmpfs filesystem
    #
    # @see DeleteDevice
    class DeleteTmpfs < DeleteDevice
      def initialize(*args)
        textdomain "storage"
        super
      end

      private

      # Deletes the indicated filesystem (see {DeleteDevice#device})
      def delete
        log.info "deleting tmpfs #{device}"
        device_graph.remove_tmpfs(device)
      end

      # @see DeleteDevice#confirm
      def confirm
        text = format(
          # TRANSLATORS: Message when deleting a Tmpfs filesystem, where %{mount_path} is replaced by a
          #   mount path (e.g., "/tmp").
          _("Really delete the temporary file system mounted at %{mount_path}?"),
          mount_path: device.mount_path
        )

        Yast2::Popup.show(text, buttons: :yes_no) == :yes
      end
    end
  end
end
