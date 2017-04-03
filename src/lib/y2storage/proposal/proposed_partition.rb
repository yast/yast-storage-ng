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
  end
end
