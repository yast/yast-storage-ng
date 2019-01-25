# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2storage/bcache"

module Y2Storage
  # A Backed Bcache device
  #
  # A Backed Bcache device represents a block device that uses a caching set for caching
  # read/write operations (although the caching set is optional). The Backed Bcache device
  # is created over a backing device, and the backing device can be any block device.
  #
  # A Backed Bcache device could use none caching set at all, so IO is directly performed
  # over the backing device.
  #
  # This is a wrapper for Storage::BackedBcache
  class BackedBcache < Bcache
    wrap_class Storage::BackedBcache

    # @!method bcache_cset
    #   @return [BcacheCset, nil] returns associated bcache cset
    storage_forward :bcache_cset, as: "BcacheCset", check_with: :has_bcache_cset

    # @!method attach_bcache_cset(set)
    #   @param set [BcacheCset] set to attach
    #   @raise [storage::Exception] if attaching failed
    storage_forward :attach_bcache_cset

    # @!method backing_device
    #   @return [BlkDevice] returns the backing device used by this bcache
    storage_forward :backing_device, as: "BlkDevice"

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
    #   @return [BackedBcache]
    storage_class_forward :create, as: "BackedBcache"

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<BackedBcache>] all Backed Bcache devices in the given devicegraph,
    #     in no particular order
    storage_class_forward :all, as: "BackedBcache"

    def inspect
      if bcache_cset
        "<BackedBcache #{name} #{bcache_cset.inspect} -> #{backing_device.inspect}>"
      else
        "<BackedBcache #{name} without caching set -> #{backing_device.inspect}>"
      end
    end

  protected

    def types_for_is
      super << :backed_bcache
    end
  end
end
