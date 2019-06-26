#!/usr/bin/env ruby
#
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

require "yast"
require "y2storage/partition_tables/type"

module Y2Storage
  # Mixin for devices that, from the libstorage point of view, are basically
  # an aggregation of several disks. I.e. Multipath I/O or BIOS RAID.
  module MultiDiskDevice
    # Checks whether this is a network device.
    #
    # @return [Boolean] true if any of disks is network-based
    def in_network?
      parents.any? { |i| i.respond_to?(:in_network?) && i.in_network? }
    end

    # Checks whether some of the disks of the device are connected through USB.
    #
    # Although that is obviously very unlikely, this method is offered for
    # symmetry reasons in relation to other disk-like devices like {Disk} or
    # {Dasd}.
    #
    # @return [Boolean]
    def usb?
      parents.any? { |i| i.respond_to?(:usb?) && i.usb? }
    end

    # Default partition table type for newly created partition tables
    # @see Partitionable#preferred_ptable_type
    #
    # Assume the same value used for individual disks (GPT).
    #
    # @return [PartitionTables::Type]
    def preferred_ptable_type
      # We always suggest GPT
      PartitionTables::Type::GPT
    end
  end
end
