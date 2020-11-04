# Copyright (c) [2019-2020] SUSE LLC
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
    # Action for deleting a Btrfs filesystem
    #
    # @see DeleteDevice
    class DeleteBtrfs < DeleteDevice
      def initialize(*args)
        super
        textdomain "storage"
      end

      private

      # Deletes the indicated filesystem (see {DeleteDevice#device})
      def delete
        log.info "deleting btrfs #{device}"
        device.blk_devices.first.delete_filesystem
      end

      # @see DeleteDevice#confirm
      def confirm
        # TRANSLATORS: Message when deleting a Btrfs filesystem, where %{name} is replaced by the Btrfs
        #   name (e.g., "BtrFS sda1").
        text = format(_("Really delete the file system %{name}?"), name: device.name)

        Yast2::Popup.show(text, buttons: :yes_no) == :yes
      end

      # @see DeleteDevice#committed_device
      def committed_device
        @committed_device ||= system_graph.find_device(device.sid)
      end

      # @see DeleteDevice#try_unmount?
      def try_unmount?
        return false unless committed_device

        committed_device.active_mount_point?
      end

      # Devicegraph that represents the current version of the devices in the system
      #
      # @note To check whether a filesystem is currently mounted, it must be checked
      #   in the system devicegraph. When a mount point is "immediate deactivated", the
      #   mount point is set as inactive only in the system devicegraph.
      #
      # @return [Y2Storage::Devicegraph]
      def system_graph
        Y2Storage::StorageManager.instance.system
      end
    end
  end
end
