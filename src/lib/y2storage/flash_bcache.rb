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
  # A Flash-only Bcache device
  #
  # A Flash-only Bcache is an special type of bcache. It has no backing device,
  # and it is directly created over a caching set.
  #
  # Several Flash-only Bcache devices can be created over the same cset. They can
  # be used as a regular block device.
  #
  # This is a wrapper for Storage::FlashBcache
  class FlashBcache < Bcache
    wrap_class Storage::FlashBcache

    # @!method bcache_cset
    #   @return [BcacheCset] returns the caching set in which the Flash-only Bcache
    #     is created over.
    storage_forward :bcache_cset, as: "BcacheCset"

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<FlashBcache>] all Flash-only Bcache devices in the given devicegraph,
    #     in no particular order
    storage_class_forward :all, as: "FlashBcache"

    def inspect
      "<FlashBcache #{name} (#{size}) -> #{bcache_cset.inspect}>"
    end

  protected

    def types_for_is
      super << :flash_bcache
    end
  end
end
