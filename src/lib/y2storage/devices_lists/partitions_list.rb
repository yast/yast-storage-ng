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
require "y2storage/devices_lists/disks_list"
require "y2storage/devices_lists/filesystems_list"
require "y2storage/devices_lists/encryptions_list"
require "y2storage/devices_lists/formattable"

module Y2Storage
  module DevicesLists
    # List of partitions from a devicegraph
    # @deprecated See DevicesList::Base
    class PartitionsList < Base
      list_of ::Storage::Partition
      include Formattable

      # Filesystems located in the partitions, either directly or through an
      # encryption device
      #
      # @return [FilesystemsList]
      def filesystems
        enc_list, fs_list = direct_encryptions_and_filesystems
        fs_list.concat(EncryptionsList.new(devicegraph, list: enc_list).filesystems.to_a)
        FilesystemsList.new(devicegraph, list: fs_list)
      end

      # Encryption devices located in the partitions
      #
      # @return [EncryptionsList]
      def encryptions
        enc_list, _fs_list = direct_encryptions_and_filesystems
        EncryptionsList.new(devicegraph, list: enc_list)
      end

      # Disks containing the partitions
      #
      # @return [DisksList]
      def disks
        disks = list.map { |partition| Storage.to_disk(partition.partitionable) }
        disks.uniq! { |s| s.sid }
        DisksList.new(devicegraph, list: disks)
      end

    protected

      def full_list
        # There is no ::Storage::Partition.all in libstorage API
        devicegraph.all_disks.to_a.reduce([]) do |sum, disk|
          begin
            sum + disk.partition_table.partitions.to_a
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
            # No partition table
            sum
          end
        end
      end
    end
  end
end
