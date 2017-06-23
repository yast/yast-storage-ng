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

require "y2storage/storage_class_wrapper"
require "y2storage/partitionable"
require "y2storage/md_level"
require "y2storage/md_parity"

module Y2Storage
  # A MD RAID
  #
  # This is a wrapper for Storage::Md
  class Md < Partitionable
    wrap_class Storage::Md

    # @!method self.create(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String]
    #   @return [Md]
    storage_class_forward :create, as: "Md"

    # @!method devices
    #   @return [Array<BlkDevice>] block devices used by the MD RAID
    storage_forward :devices, as: "BlkDevice"

    # @!method add_device(blk_device)
    #   Adds a block device to the MD RAID.
    #
    #   @param blk_device [BlkDevice]
    storage_forward :add_device

    # @!method remove_device(blk_device)
    #   Removes a block device from the MD RAID.
    #
    #   @param blk_device [BlkDevice]
    storage_forward :remove_device

    # @!method numeric?
    #   @return [Boolean] whether the MD RAID has a numeric name
    storage_forward :numeric?

    # @!method number
    #   @return [Int] the number of the MD RAID.
    storage_forward :number

    # @!attribute md_level
    #   RAID level of the MD RAID.
    #   @return [MdLevel]
    storage_forward :md_level, as: "MdLevel"
    storage_forward :md_level=

    # @!attribute md_parity
    #   Parity of the MD RAID.
    #   @return [MdParity]
    storage_forward :md_parity, as: "MdParity"
    storage_forward :md_parity=

    # @!attribute chunk_size
    #   Chunk size of the MD RAID.
    #   @return [DiskSize]
    storage_forward :chunk_size, as: "DiskSize"
    storage_forward :chunk_size=

    # @!attribute uuid
    #   @return [String] the UUID of the MD RAID.
    storage_forward :uuid

    # @!attribute superblock_version
    #   @return [String] superblock version of the MD RAID.
    storage_forward :superblock_version

    # @!attribute in_etc_mdadm
    #  Whether the MD RAID is included in /etc/mdadm.conf
    storage_forward :in_etc_mdadm?
    storage_forward :in_etc_mdadm=

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Md>] all the mds in the given devicegraph
    storage_class_forward :all, as: "Md"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String] kernel-style device name (e.g. "/dev/md0" or /dev/md/test)
    #   @return [Md] nil if there is no such md
    storage_class_forward :find_by_name, as: "Md"

    # @!method self.find_by_name(devicegraph, name)
    #   @return [String] next free numeric name for a MD RAID
    storage_class_forward :find_free_numeric_name

    def inspect
      "<Md #{name} #{size} #{md_level}>"
    end

    # Default partition table type for newly created partition tables
    # @see Partitionable#preferred_ptable_type
    #
    # @return [PartitionTables::Type]
    def preferred_ptable_type
      # We always suggest GPT
      PartitionTables::Type.find(:gpt)
    end

  protected

    def types_for_is
      super << :md
    end
  end
end
