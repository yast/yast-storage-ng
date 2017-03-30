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
    # List of encryption devices (i.e. LUKS) from a devicegraph
    #
    # This list works under the assumption that the encryption device sits on
    # top of a disk, a partition or a logical volume
    # @deprecated See DevicesList::Base
    class EncryptionsList < Base
      list_of ::Storage::Encryption

      # Filesystems located in the encryption devices
      #
      # @return [FilesystemsList]
      def filesystems
        fs_list = list.map do |encryption|
          begin
            encryption.filesystem
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
            # No filesystem in the encryption device
            nil
          end
        end
        FilesystemsList.new(devicegraph, list: fs_list.compact)
      end

      # Disks hosting the encryption devices, either directly or through
      # a partition
      #
      # @return [DisksList]
      def disks
        disks = blk_devices_of_type(:disk)
        part_disks = partitions.disks.to_a
        list = disks + part_disks
        DisksList.new(devicegraph, list: list.uniq { |d| d.sid })
      end

      # Partitions hosting the encryptions
      #
      # @return [PartitionsList]
      def partitions
        partitions = blk_devices_of_type(:partition)
        PartitionsList.new(devicegraph, list: partitions)
      end

      # LVM logical volumes hosting the encryptions
      #
      # @return [LvmLvsList]
      def lvm_lvs
        lvs = blk_devices_of_type(:lvm_lv)
        LvmLvsList.new(devicegraph, list: lvs)
      end

      alias_method :lvs, :lvm_lvs
      alias_method :logical_volumes, :lvm_lvs
    end
  end
end
