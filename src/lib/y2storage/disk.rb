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
require "y2storage/free_disk_space"
require "y2storage/data_transport"
require "y2storage/disk_device"

module Y2Storage
  # A physical disk device
  #
  # This is a wrapper for Storage::Disk
  class Disk < Partitionable
    wrap_class Storage::Disk
    include DiskDevice

    # @!method rotational?
    #   @return [Boolean] whether this is a rotational device
    storage_forward :rotational?

    # @!method transport
    #   @return [DataTransport]
    storage_forward :transport, as: "DataTransport"

    # @!method self.create(devicegraph, name, region_or_size = nil)
    #   @param devicegraph [Devicegraph]
    #   @param name [String]
    #   @param region_or_size [Region, DiskSize]
    #   @return [Disk]
    storage_class_forward :create, as: "Disk"

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Disk>] all the disks in the given devicegraph,
    #     in no particular order
    storage_class_forward :all, as: "Disk"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String] kernel-style device name (e.g. "/dev/sda")
    #   @return [Disk] nil if there is no such disk
    storage_class_forward :find_by_name, as: "Disk"

    def inspect
      "<Disk #{name} #{size}>"
    end

    # Checks if it's an USB disk
    #
    # @return [Boolean]
    def usb?
      transport.to_sym == :usb
    end

    # Checks if it's in network
    #
    # @return [Boolean]
    def in_network?
      transport.network?
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
      super << :disk
    end


    # Whether this device can be in general treated like a disk for YaST
    # purposes
    #
    # @see Devicegraph::disk_devices
    #
    # @return [Boolean]
    def disk_device?
      puts "xxxxx"
      super
#      basename.match?(xxxx) ? false : super
    end

  end
end
