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
require "y2storage/proposal/proposed_device"

module Y2Storage
  # Class to represent a planned volume (partition or logical volume) and
  # its constraints
  #
  class ProposedPartition < ProposedDevice
    # @return [::Storage::IdNum] id of the partition in a ms-dos style
    # partition table. If nil, the final id is expected to be inferred from
    # the filesystem type.
    attr_accessor :partition_id
    # @return [String] device name of the disk in which the volume has to be
    # located. If nil, the volume can be allocated in any disk.
    attr_accessor :disk
    # @return [DiskSize] maximum distance from the start of the disk in which
    # the partition can start
    attr_accessor :max_start_offset
    # FIXME: this one is just guessing the final API of alignment
    # @return [Symbol] modifier to pass to ::Storage::Region#align when
    # creating the volume. :keep_size to avoid size changes. nil to use
    # default alignment.
    attr_accessor :align
    # @return [Boolean] whether the boot flag should be set. Expected to be
    # used only with ms-dos style partition tables. GPT has a similar legacy
    # flag but is not needed in our grub2 setup.
    attr_accessor :bootable

    # Constructor.
    #
    # @param mount_point [string] @see #mount_point
    # @param filesystem_type [::Storage::FsType] @see #filesystem_type
    def initialize(volume: nil, target: nil)
      @partition_id     = nil
      @disk             = nil
      @max_start_offset = nil
      @align            = nil
      @bootable         = nil
      super
    end

    # Checks whether the volume represents an LVM physical volume
    #
    # @return [Boolean]
    def lvm_pv?
      partition_id == Storage::ID_LVM
    end

    # Returns the volume that must be placed at the end of a given space in
    # order to make all the volumes in the list fit there.
    #
    # This method only returns something meaningful if the only way to make the
    # volumes fit into the space is ensuring one particular volume will be at
    # the end. That corner case can only happen if the size of the given spaces
    # is not divisible by min_grain.
    #
    # If the volumes fit in any order or if it's impossible to make them fit,
    # the method returns nil.
    #
    # @param size_to_fill [DiskSize]
    # @param min_grain [DiskSize]
    # @return [PlannedVolume, nil]
    def self.enforced_last(proposed_partitions, size_to_fill, min_grain)
      rounded_up = disk_size(proposed_partitions, rounding: min_grain)
      # There is enough space to fit with any order
      return nil if size_to_fill >= rounded_up

      missing = rounded_up - size_to_fill
      # It's impossible to fit
      return nil if missing >= min_grain

      proposed_partitions.detect do |partition|
        target_size = partition.disk_size
        target_size.ceil(min_grain) - missing >= target_size
      end
    end
  end
end
