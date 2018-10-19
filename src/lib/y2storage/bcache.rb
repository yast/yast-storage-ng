# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
  # A Bcache device
  #
  # This is a wrapper for Storage::Bcache
  class Bcache < Partitionable
    wrap_class Storage::Bcache

    # @!method bcache_cset
    #   @return [BcacheCset, nil] returns associated bcache cset
    storage_forward :bcache_cset, as: "BcacheCset", check_with: :has_bcache_cset

    # @!method attach_bcache_cset(set)
    #   @param set [BcacheCset] set to attach
    #   @raise if attaching failed
    storage_forward :attach_bcache_cset

    # @!method blk_device
    #   @return [BlkDevice] returns a backing device for cache
    storage_forward :blk_device, as: "BlkDevice"

    # @!attribute cache_mode
    #   Mode in which cache operates.
    #   @return [CacheMode]
    storage_forward :cache_mode, as: "CacheMode"
    storage_forward :cache_mode=

    # @!attribute writeback_percent
    #   Target percent of dirty pages in writeback mode.
    #   @return [Integer]
    storage_forward :writeback_percent
    storage_forward :writeback_percent=

    # @!attribute sequential_cutoff
    #   Size for cache consider read as sequential and do not cache it.
    #   @return [DiskSize]
    storage_forward :sequential_cutoff, as: "DiskSize"
    storage_forward :sequential_cutoff=

    # @!method self.create(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String]
    #   @return [Bcache]
    storage_class_forward :create, as: "Bcache"

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Bcache>] all the bcache devices in the given devicegraph,
    #     in no particular order
    storage_class_forward :all, as: "Bcache"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String] kernel-style device name (e.g. "/dev/bcache0")
    #   @return [Bcache] nil if there is no such device
    storage_class_forward :find_by_name, as: "Bcache"

    # @!method self.find_free_name(devicegraph)
    #   Returns available free name for bcache device.
    #   @param devicegraph [Devicegraph] in which search for free name
    #   @return [String] full path to new bcache device like "/dev/bcache3"
    storage_class_forward :find_free_name

    def inspect
      "<Bcache #{name} #{bcache_cset.inspect} -> #{blk_device}>"
    end

  protected

    def types_for_is
      super << :bcache
    end
  end
end
