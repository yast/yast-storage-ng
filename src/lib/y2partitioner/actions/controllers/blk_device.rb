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
require "y2storage"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Actions
    module Controllers
      # This class offers helper methods to perform actions over a block device,
      # for example, to check if its filesystem exists on disk, it is mounted, etc.
      class BlkDevice
        # Block device
        #
        # @return [Y2Storage::BlkDevice]
        attr_reader :device

        # Constructor
        #
        # @raise [TypeError] if device is not a block device.
        #
        # @param device [Y2Storage::BlkDevice] it has to be a block device,
        #   (i.e., device#is?(:blk_device) #=> true).
        def initialize(device)
          raise(TypeError, "param device has to be a block device") unless device.is?(:blk_device)

          @device = device
        end

        # Whether the current filesystem of the device exists on the system
        #
        # @note The device could have a new filesystem that does not match to the real filesystem
        #   that actually exists on disk (e.g., after formatting the device).
        #
        # @return [Boolean]
        def committed_current_filesystem?
          return false unless device.formatted?

          committed_filesystem? &&
            committed_filesystem.sid == device.filesystem.sid
        end

        # Whether the filesystem of the device exists on the system and it is mounted
        #
        # @note The filesystem on system is checked, independently of it matches to the current
        #   filesystem of the device.
        #
        # @return [Boolean]
        def mounted_committed_filesystem?
          return false unless committed_filesystem?

          mount_point = committed_filesystem.mount_point

          !mount_point.nil? && mount_point.active?
        end

        # Whether the device exists on the system
        #
        # @return [Boolean] true if the device exists on disk; false otherwise.
        def committed_device?
          !committed_device.nil?
        end

        # Device taken from the system devicegraph
        #
        # @return [Y2Storage::BlkDevice, nil] nil if the device does not exist on disk yet.
        def committed_device
          @committed_device ||= system_devicegraph.find_device(device.sid)
        end

        # Whether the committed device is formatted (see {#committed_device})
        #
        # @return [Boolean] true if the device exists on disk and it is formatted;
        #   false otherwise.
        def committed_filesystem?
          !committed_filesystem.nil?
        end

        # Filesystem of the committed device (see {#committed_device})
        #
        # @return [Y2Storage::BlkFilesystem, nil] nil if the device does not exist on disk or
        #   it is not formatted.
        def committed_filesystem
          return nil unless committed_device?

          committed_device.filesystem
        end

        # Whether the device needs to be unmounted to resize it (shrink)
        #
        # @note The filesystem must be unmounted when it exists on disk, it is mounted and
        #   it does not support mounted shrink.
        #
        # @return [Boolean]
        def need_unmount_for_shrinking?
          return false unless mounted_committed_filesystem?

          !committed_filesystem.supports_mounted_shrink?
        end

        # Whether the device needs to be unmounted to resize it (grow)
        #
        # @note The filesystem must be unmounted when it exists on disk, it is mounted and
        #   it does not support mounted grow.
        #
        # @return [Boolean]
        def need_unmount_for_growing?
          return false unless mounted_committed_filesystem?

          !committed_filesystem.supports_mounted_grow?
        end

      private

        # Devicegraph that represents the current version of the devices in the system
        #
        # @note To check whether a filesystem is currently mounted, it must be checked
        #   in the system devicegraph. When a mount point is "immediate deactivated", the
        #   mount point is set as inactive only in the system devicegraph.
        #
        # @return [Y2Storage::Devicegraph]
        def system_devicegraph
          Y2Storage::StorageManager.instance.system
        end
      end
    end
  end
end
