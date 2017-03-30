#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
require "storage"
require "y2storage/disk_size"

module Y2Storage
  #
  # Helper class to keep information about free disk space together.
  #
  class FreeDiskSpace
    attr_reader :region, :disk

    # Initialize.
    #
    # @param disk [::Storage::Disk]
    #
    # @param region [::Storage::Region]
    #
    def initialize(disk, region)
      @disk = disk
      # Store a duplicate of the original region, which could change or be
      # deleted (don't trust the garbage collector when SWIG is involved)
      # TODO: #to_storage_value to be removed when adapting this class
      region = region.to_storage_value if region.respond_to?(:to_storage_value)
      @region = Storage::Region.new(region)
    end

    # Return the name of the disk this slot is on.
    #
    # @return [String] disk_name
    #
    def disk_name
      @disk.name
    end

    # Return the size of this slot.
    #
    # @return [DiskSize]
    #
    def disk_size
      DiskSize.B(region.length * region.block_size)
    end

    # Offset of the slot relative to the beginning of the disk
    #
    # @return [DiskSize]
    #
    def start_offset
      DiskSize.B(region.start * region.block_size)
    end

    def to_s
      "#<FreeDiskSpace disk_name=#{disk_name}, size=#{disk_size}, start_offset=#{start_offset}>"
    end
  end
end
