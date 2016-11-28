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
    # List of LVM physical volumes from a devicegraph
    class LvmPvsList < Base
      list_of ::Storage::LvmPv

      # Volume groups containing the physical volumes
      #
      # @return [LvmVgsList]
      def lvm_vgs
        vgs_list = list.map do |pv|
          begin
            pv.lvm_vg
          rescue ::Storage::WrongNumberOfChildren
            # Unassigned physical volume
            nil
          end
        end
        vgs_list.compact!
        vgs_list.uniq! { |vg| vg.sid }
        LvmVgsList.new(devicegraph, list: vgs_list)
      end

      alias_method :vgs, :lvm_vgs
      alias_method :volume_groups, :lvm_vgs

      # Partitions containing the physical volumes
      #
      # @return [PartitionsList]
      def partitions
        partitions = blk_devices.select do |device|
          Storage.partition?(device)
        end
        partitions.map! { |p| Storage.to_partition(p) }
        PartitionsList.new(devicegraph, list: partitions)
      end

      # Disks containing the physical volumes, either directly or
      # through a partition.
      #
      # @return [DisksList]
      def disks
        disks = blk_devices.select do |device|
          Storage.disk?(device)
        end
        disks.map! { |d| Storage.to_partition(d) }
        part_disks = partitions.disks.to_a
        list = disks + part_disks
        DisksList.new(devicegraph, list: list.uniq { |d| d.sid })
      end

    protected

      def blk_devices
        list.map(&:blk_device).flatten.uniq
      end
    end
  end
end
