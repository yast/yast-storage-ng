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

module Y2Storage
  # A multipath device
  #
  # This is a wrapper for Storage::Multipath
  class Multipath < Partitionable
    wrap_class Storage::Multipath

    # @!method rotational?
    #   @return [Boolean] whether this is a rotational device
    storage_forward :rotational?

    # @!method self.create(devicegraph, name, region_or_size = nil)
    #   @param devicegraph [Devicegraph]
    #   @param name [String]
    #   @param region_or_size [Region, DiskSize]
    #   @return [Multipath]
    storage_class_forward :create, as: "Multipath"

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Multipath>] all the multipath devices in the given
    #     devicegraph, sorted by name
    storage_class_forward :all, as: "Multipath"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String] only the name returned by #name is considered
    #   @return [Multipath] nil if there is no such device
    storage_class_forward :find_by_name, as: "Multipath"

    def inspect
      "<Multipath #{name} parents=#{parents}>"
    end

    # Checks if it's in network
    #
    # @return [Boolean]
    def in_network?
      parents.any? { |i| i.respond_to?(:in_network?) && i.in_network? }
    end

    # Checks whether some of the devices of the multipath are connected through
    # USB.
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
    # @return [PartitionTables::Type]
    def preferred_ptable_type
      # We always suggest GPT
      PartitionTables::Type::GPT
    end

  protected

    def types_for_is
      super << :multipath
    end
  end
end
