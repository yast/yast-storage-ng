# Copyright (c) [2021] SUSE LLC
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

require "y2storage/storage_manager"
require "y2partitioner/dialogs/unmount"

module Y2Partitioner
  # Mixin for recursively unmounting a device
  #
  # Recursively unmounting consists on trying to unmount a device and all its mounted descendants.
  # For example, given a LVM Volume Group, the mounted filesystems from its Logical Volumes will be
  # consider as candidates to be unmounted.
  module RecursiveUnmount
    # Shows a dialog for recursively unmounting a device
    #
    # @see Dialogs::Unmount
    #
    # @param device [Y2Storage::Device]
    # @param note [String] optional note to show in the dialog
    #
    # @return [Boolean] true if all the affected devices were unmounted or the user decides to continue;
    #   false otherwise.
    def recursive_unmount(device, note: nil)
      mounted_devices = find_mounted_devices(device)

      return true if mounted_devices.none?

      Dialogs::Unmount.new(mounted_devices, note:).run == :finish
    end

    # Finds devices that are currently mounted in the system
    #
    # @param device [Y2Storage::Device]
    # @return [Array<Y2Storage::Mountable>]
    def find_mounted_devices(device)
      system_device = system_graph.find_device(device.sid)

      return [] unless system_device

      mount_points = system_device.descendants(Y2Storage::View::REMOVE).select do |dev|
        dev.is?(:mount_point)
      end

      mounted_devices = mount_points.map(&:mountable).select(&:active_mount_point?)

      # Only devices living in the same devicegraph as the given device are considered. This avoids to
      # bother the user by asking for unmounting devices too many times. For example, when a subvolume is
      # deleted, if the user decides to continue without unmounting, then we do not want ask for such
      # subvolume again in case that the Btrfs filesystem is deleted afterwards.
      current_graph = device.devicegraph
      mounted_devices.map { |d| current_graph.find_device(d.sid) }.compact
    end

    # Devicegraph that represents the current version of the devices in the system
    #
    # To check whether a device is currently mounted, it must be checked in the system devicegraph. When
    # a mount point is "deactivated", the mount point is set as inactive only in the system devicegraph.
    #
    # @return [Y2Storage::Devicegraph]
    def system_graph
      Y2Storage::StorageManager.instance.system
    end
  end
end
