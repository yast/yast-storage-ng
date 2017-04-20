# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "y2storage/storage_enum_wrapper"

module Y2Storage
  # Class to represent all the possible partition ids
  #
  # This is a wrapper for the Storage::ID enum
  class PartitionId
    include StorageEnumWrapper

    wrap_enum "ID"

    LINUX_SYSTEM_IDS = [LINUX, SWAP, LVM, RAID]

    WINDOWS_SYSTEM_IDS = [NTFS, DOS32, DOS16, DOS12, WINDOWS_BASIC_DATA, MICROSOFT_RESERVED]

    private_constant :LINUX_SYSTEM_IDS, :WINDOWS_SYSTEM_IDS

    # Set of ids for partitions that are typically part of a Linux system.
    # This may be a normal Linux partition (type 0x83), a Linux swap partition
    # (type 0x82), an LVM partition, or a RAID partition.
    #
    # @return [Array<PartitionId>]
    def self.linux_system_ids
      LINUX_SYSTEM_IDS.dup
    end

    # Set of ids for partitions that could potentially host a MS Windows system.
    #
    # Take into account that checking the partition id is not enough to ensure a
    # partition is suitable to host a MS Windows installation (for example,
    # Windows can only be installed in primary partitions).
    #
    # @return [Array<PartitionId>]
    def self.windows_system_ids
      WINDOWS_SYSTEM_IDS.dup
    end

    # @see StorageEnumWrapper#is?
    #
    # In addition to checking by name, it also supports :linux_system and
    # :windows_system
    #
    # @see .linux_system_ids
    # @see .windows_system_ids
    def is?(*names)
      names.any? do |name|
        case name.to_sym
        when :linux_system
          LINUX_SYSTEM_IDS.include?(self)
        when :windows_system
          WINDOWS_SYSTEM_IDS.include?(self)
        else
          name.to_sym == to_sym
        end
      end
    end
  end
end
