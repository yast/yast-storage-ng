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

module Y2Storage
  # Class representing a certain space in a block device.
  #
  # Basically a start/length pair with a block size.
  #
  # This is a wrapper for Storage::Region, but has a fundamental difference.
  # Y2Storage::Region.new receives the Storage::Region object to wrap as the
  # only parameter (as usual with Storage wrappers). To create an instance from
  # scratch (generating the corresponding Storage::Region in the process), use
  # Y2Storage::Region.create, that gets the same arguments than
  # Storage::Region.new.
  # @see StorageClassWrapper
  class Region
    include StorageClassWrapper
    wrap_class Storage::Region

    # @!method empty?
    #   @return [Boolean]
    storage_forward :empty?

    # @!attribute start
    #   @return [Fixnum] number of the first sector of the region
    storage_forward :start
    storage_forward :start=

    # @!attribute length
    #   @return [Fixnum] number of sectors in the region
    storage_forward :length
    storage_forward :length=

    # @!attribute block_size
    #   @return [DiskSize] size of a single sector
    storage_forward :block_size, as: "DiskSize"
    storage_forward :block_size=

    # @!method end
    #   @return [Fixnum] position of the last sector of the region
    storage_forward :end

    # @!method adjust_start(delta)
    #   Moves the region by adding "delta" sectors to the start
    #
    #   @raise [Storage::Exception] if trying to move the region before the
    #     start of the device
    #
    #   @param delta [Fixnum] can be negative
    storage_forward :adjust_start

    # @!method adjust_length(delta)
    #   Resizes the region by adding "delta" sectors to the length
    #
    #   @raise [Storage::Exception] if trying to shrink the region to a negative
    #     size
    #
    #   @param delta [Fixnum]
    storage_forward :adjust_length

    # @!method <(other)
    #   Checks whether the region starts before the other
    #
    #   @raise [Storage::DifferentBlockSizes] when comparing regions with
    #     different block sizes
    #
    #   @note This class does not include Comparable because, according to the
    #     definitions of the operands, two regions can be different while none
    #     of them is bigger than the other.
    storage_forward :<

    # @!method >(other)
    #   Checks whether the region starts after the other
    #
    #   @raise [Storage::DifferentBlockSizes] when comparing regions with
    #     different block sizes
    #
    #   @see #<
    storage_forward :>

    # @!method ==(other)
    #   Checks whether the regions are equivalent (same start and length)
    #
    #   @raise [Storage::DifferentBlockSizes] when comparing regions with
    #     different block sizes
    #
    #   @note This class does not include Comparable because, according to the
    #     definitions of the operands, two regions can be different while none
    #     of them is bigger than the other.
    storage_forward :==

    # @!method !=(other)
    #   @see #==
    #
    #   @raise [Storage::DifferentBlockSizes] when comparing regions with
    #     different block sizes
    storage_forward :!=

    def inspect
      "<Region range: #{show_range}, block_size: #{block_size}>"
    end

    def show_range
      "#{start} - #{self.end}"
    end

    alias_method :to_s, :inspect

    # Creates a new object generating the corresponding Storage::Region object
    # and wrapping it.
    #
    # @param start [Fixnum] starting sector number
    # @param length [Fixnum] sector count
    # @param block_size [Fixnum] sector size in bytes
    # @return [Region]
    def self.create(start, length, block_size)
      new(Storage::Region.new(start, length, block_size.to_i))
    end
  end
end
