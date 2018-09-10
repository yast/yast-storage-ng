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

module Y2Storage
  # A Bcache caching set
  #
  # This is a wrapper for Storage::BcacheCset
  class BcacheCset < Device
    wrap_class Storage::BcacheCset

    # @!method blk_devices
    #   @return [Array<BlkDevice>] returns a list of devices used as caching ones in this set
    storage_forward :blk_devices, as: "BlkDevice"

    # @!method uuid
    #   @return [String] returns an UUID of set
    storage_forward :uuid

    # @!method self.create(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [BcacheCset]
    storage_class_forward :create, as: "Bcache"

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<BcacheCset>] all the bcachescsets in the given devicegraph,
    #     in no particular order
    storage_class_forward :all, as: "BcacheCset"

    def inspect
      "<BcacheCset #{uuid} #{blk_devices.inspect}>"
    end

  protected

    def types_for_is
      super << :bcache_cset
    end
  end
end
