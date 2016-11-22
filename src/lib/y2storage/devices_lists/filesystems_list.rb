#
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "storage"
require "y2storage/devices_lists/base"

module Y2Storage
  module DevicesLists
    # List of filesystems from a devicegraph
    class FilesystemsList < Base
      list_of ::Storage::Filesystem

      # Subset of the list filtered by mount point
      #
      # @see #with
      #
      # @param [String, Array<String>] single mount point or array of possible
      #     values
      # @return [FilesystemsList]
      def with_mountpoint(value)
        with do |fs|
          if value.is_a?(Enumerable)
            fs.mountpoints.any? { |mp| value.include?(mp) }
          else
            fs.mountpoints.include?(value)
          end
        end
      end

      # Disks hosting the filesystems, either directly or through a partition
      #
      # @return [DisksList]
      def disks
        disks = blk_devices.select do |device|
          Storage::disk?(device)
        end
        disks.map! { |d| Storage::to_disk(d) }
        part_disks = partitions.disks.to_a
        list = disks + part_disks
        DisksList.new(devicegraph, list: list.uniq { |d| d.sid })
      end

      # Partitions hosting the filesystems
      #
      # @return [PartitionsList]
      def partitions
        partitions = blk_devices.select do |device|
          Storage::partition?(device)
        end
        partitions.map! { |p| Storage::to_partition(p) }
        PartitionsList.new(devicegraph, list: partitions)
      end

      # LVM logical volumes hosting the filesystems
      #
      # @return [LvmLvsList]
      def lvm_lvs
        lvs = blk_devices.select do |device|
          Storage::lvm_lv?(device)
        end
        lvs.map! { |p| Storage::to_lvm_lv(p) }
        LvmLvsList.new(devicegraph, list: lvs)
      end

      alias_method :lvs, :lvm_lvs
      alias_method :logical_volumes, :lvm_lvs

      # LVM volume groups containing the filesystems
      #
      # @return [LvmVgsList]
      def lvm_vgs
        lvm_lvs.lvm_vgs
      end

      alias_method :vgs, :lvm_vgs
      alias_method :volume_groups, :lvm_vgs

    protected

      def blk_devices
        list.map { |fs| fs.blk_devices.to_a }.flatten.uniq
      end
    end
  end
end
