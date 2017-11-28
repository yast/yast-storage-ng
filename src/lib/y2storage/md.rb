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
  #
  # @note Some BIOS RAIDs (IMSM and DDF) can be handled by mdadm as MD RAIDs,
  #   see {MdContainer} and {MdMember} subclasses.
  class Md < Partitionable
    wrap_class Storage::Md, downcast_to: ["MdMember", "MdContainer"]

    # @!method self.create(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String] name of the new device, like "/dev/md0",
    #     "/dev/md/foo" or "/dev/md/1"
    #   @return [Md]
    storage_class_forward :create, as: "Md"

    # @!method devices
    #   @return [Array<BlkDevice>] block devices used by the MD RAID
    storage_forward :devices, as: "BlkDevice"

    # @!method add_device(blk_device)
    #   Adds a block device to the MD RAID.
    #
    #   @param blk_device [BlkDevice]
    storage_forward :add_device, raise_errors: true

    # @!method remove_device(blk_device)
    #   Removes a block device from the MD RAID.
    #
    #   @param blk_device [BlkDevice]
    storage_forward :remove_device, raise_errors: true

    # @!method numeric?
    #   @return [Boolean] whether the MD RAID has a numeric name
    storage_forward :numeric?

    # @!method number
    #   @return [Integer] the number of the MD RAID.
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

    # @!attribute metadata
    #   @return [String] metadata format of the MD RAID, e.g. "1.0" or "imsm".
    storage_forward :metadata

    # @!method in_etc_mdadm?
    #   @return [Boolean] whether the MD RAID is included in /etc/mdadm.conf
    storage_forward :in_etc_mdadm?

    # @!method in_etc_mdadm=(value)
    #   @see #in_etc_mdadm?
    #   @param value [Boolean]
    storage_forward :in_etc_mdadm=

    # @!method minimal_number_of_devices
    #   Minimal number of devices required by the RAID.
    #
    #   For RAIDs of level CONTAINER it returns 0 (those RAIDs cannot be created
    #   or modified anyway).
    #
    #   @return [Integer]
    storage_forward :minimal_number_of_devices

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Md>] all the mds in the given devicegraph
    storage_class_forward :all, as: "Md"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String] kernel-style device name (e.g. "/dev/md0" or /dev/md/test)
    #   @return [Md] nil if there is no such md
    storage_class_forward :find_by_name, as: "Md"

    # @!method self.find_free_numeric_name(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [String] next free numeric name for a MD RAID
    storage_class_forward :find_free_numeric_name

    def inspect
      md_class = self.class.name.split("::").last
      "<#{md_class} #{name} #{size} #{md_level}>"
    end

    # Whether the RAID is defined by software
    #
    # This method is used to distinguish between Software RAID and BIOS RAID,
    # see {Devicegraph#bios_raids} and {Devicegraph#software_raids}.
    #
    # All RAID classes should define this method, see {DmRaid#software_defined?},
    # {MdContainer#software_defined?} and {MdMember#software_defined?}.
    #
    # @note MD RAIDS are considered defined by sofware.
    #
    # @return [Boolean] true
    def software_defined?
      true
    end

    # Default partition table type for newly created partition tables
    # @see Partitionable#preferred_ptable_type
    #
    # @return [PartitionTables::Type]
    def preferred_ptable_type
      # We always suggest GPT
      PartitionTables::Type.find(:gpt)
    end

    # Raw (non encrypted) versions of the devices included in the MD array.
    #
    # If none of the devices is encrypted, this is equivalent to #devices,
    # otherwise it returns the original devices instead of the encryption ones.
    #
    # @return [Array<BlkDevice>]
    def plain_devices
      devices.map(&:plain_device)
    end

    # Name of the named RAID, if any
    #
    # @return [String, nil] nil if this is not a named array
    def md_name
      return nil if numeric?
      basename
    end

    # Sets the name, effectively turning the device into a named array
    #
    # @note: Only works if the array does not exist yet in the system. Cannot be
    #   used to rename in-disk arrays.
    # @note: Trying to 'unset' the name does not turn the array back into a
    #   numeric one, it raises an exception instead.
    # @note: Is actually possible to set the array to numeric again assigning
    #   the name to mdX where X is a correct (available) number, but that
    #   behavior is not granted to work in the future.
    def md_name=(new_name)
      if new_name.nil? || new_name.empty?
        raise ArgumentError, "Resetting the name back to numeric is not supported"
      end
      self.name = "/dev/md/#{new_name}"
    end

  protected

    def types_for_is
      super << :md
    end
  end
end
