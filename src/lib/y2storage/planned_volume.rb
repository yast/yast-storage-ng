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
require "y2storage/disk_size"

module Y2Storage
  # Class to represent a planned volume (partition or logical volume) and
  # its constraints
  #
  class PlannedVolume
    # @return [String] mount point for this volume. This might be a real mount
    # point ("/", "/boot", "/home") or a pseudo mount point like "swap".
    attr_accessor :mount_point
    # @return [::Storage::FsType] the type of filesystem this volume should
    # get, like ::Storage::FsType_BTRFS or ::Storage::FsType_SWAP. A value of
    # nil means the volume will not be formatted.
    attr_accessor :filesystem_type
    # @return [String] device name of an existing partition to reuse for this
    # purpose. That means that no new partition will be created and, thus,
    # most of the other attributes (with the obvious exception of mount_point)
    # will be most likely ignored
    attr_accessor :reuse
    # @return [::Storage::IdNum] id of the partition in a ms-dos style
    # partition table. If nil, the final id is expected to be inferred from
    # the filesystem type.
    attr_accessor :partition_id
    # @return [String] device name of the disk in which the volume has to be
    # located. If nil, the volume can be allocated in any disk.
    attr_accessor :disk
    # @return [DiskSize] definitive size of the volume
    attr_accessor :disk_size
    # @return [DiskSize] minimum acceptable size in case it's not possible to
    # ensure the desired one. @see #desired_size
    attr_accessor :min_disk_size
    # @return [DiskSize] maximum acceptable size
    attr_accessor :max_disk_size
    # @return [DiskSize] preferred size
    attr_accessor :desired_disk_size
    # @return [Float] factor used to distribute the extra space between
    # volumes
    attr_accessor :weight
    # @return [Boolean] whether the volume can be placed in LVM
    attr_accessor :can_live_on_logical_volume
    # @return [String] name to use if the volume is placed in LVM
    attr_accessor :logical_volume_name
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
    # @return [String] label to enforce in the filesystem
    attr_accessor :label
    # @return [String] UUID to enforce in the filesystem
    attr_accessor :uuid

    TO_STRING_ATTRS = [:mount_point, :reuse, :min_disk_size, :max_disk_size,
                       :desired_disk_size, :disk, :max_start_offset]

    alias_method :desired, :desired_disk_size
    alias_method :min, :min_disk_size
    alias_method :max, :max_disk_size
    alias_method :desired=, :desired_disk_size=
    alias_method :min=, :min_disk_size=
    alias_method :max=, :max_disk_size=

    # Constructor.
    #
    # @param mount_point [string] @see #mount_point
    # @param filesystem_type [::Storage::FsType] @see #filesystem_type
    def initialize(mount_point, filesystem_type = nil)
      @mount_point = mount_point
      @filesystem_type = filesystem_type
      @reuse         = nil
      @partition_id  = nil
      @disk          = nil
      @disk_size     = DiskSize.zero
      @min_disk_size = DiskSize.zero
      @max_disk_size = DiskSize.unlimited
      @desired_disk_size = DiskSize.unlimited
      @max_start_offset = nil
      @align         = nil
      @bootable      = nil
      @label         = nil
      @uuid          = nil
      @weight        = 0 # For distributing extra space if desired is unlimited
      @can_live_on_logical_volume = false
      @logical_volume_name = nil

      return unless @mount_point && @mount_point.start_with?("/")
      return if @mount_point && @mount_point.start_with?("/boot")

      @can_live_on_logical_volume = true
      @logical_volume_name = if @mount_point == "/"
        "root"
      else
        @mount_point.sub(%r{^/}, "")
      end
    end

    # Minimum size that should be granted for the partition when applying a
    # given strategy
    #
    # Returns zero for reused volumes
    #
    # @param strategy [Symbol] :desired or :min
    # @return [DiskSize]
    def min_valid_disk_size(strategy)
      # No need to provide space for reused volumes
      return DiskSize.zero if reuse
      size = send(strategy)
      size = min_disk_size if size.unlimited?
      size
    end

    def to_s
      attrs = TO_STRING_ATTRS.map do |attr|
        value = send(attr)
        value = "nil" if value.nil?
        "#{attr}=#{value}"
      end
      "#<PlannedVolume " + attrs.join(", ") + ">"
    end

    # Create a filesystem for the volume on the specified partition and set its
    # mount point. Do nothing if #filesystem_type is not set.
    #
    # @param partition [::Storage::Partition]
    #
    # @return [::Storage::Filesystem] filesystem
    def create_filesystem(partition)
      return nil unless filesystem_type
      filesystem = partition.create_filesystem(filesystem_type)
      filesystem.add_mountpoint(mount_point) if mount_point && !mount_point.empty?
      filesystem.label = label if label
      filesystem.uuid = uuid if uuid
      filesystem
    end

    # Checks whether the volume represents an LVM physical volume
    #
    # @return [Boolean]
    def lvm_pv?
      partition_id == Storage::ID_LVM
    end

    def ==(other)
      other.class == self.class && other.internal_state == internal_state
    end

    # Checks whether the volume would need to reserve some extra disk space in
    # order to guarantee the partition can be created
    #
    # For more information in that regard, check the partition alignment
    # documentation at https://github.com/openSUSE/libstorage-ng
    # In short, when turning planned volumes into partitions, the size can be
    # reduced by upto approximately two times the disk grain.
    #
    # For some volumes, that's unacceptable. In that case, we need to "reserve"
    # more space than strictly needed (that is, to ensure the space is there
    # and not dedicated to any other volume).
    #
    # @param field [Symbol] :current for checking #disk_size,
    #   :desired to check #desired_disk_size, :min to check #min_disk_size
    # @param min_grain [DiskSize] minimal grain of the disk in which the
    #   partition will be created
    # @return [Boolean]
    def needs_reserved?(field, min_grain)
      size = size_for(field)

      return false if size.zero?
      align == :keep_size || size < min_reserved_size(min_grain)
    end

    # Total disk size "reserved" to turn this volume into a partition. For most
    # volumes, this is just the value of the field, but in some cases it can be
    # bigger.
    #
    # @see #needs_reserved?
    #
    # @return [DiskSize]
    def reserved_disk_size(field, min_grain)
      size = size_for(field)

      return size unless needs_reserved?(field, min_grain)
      return min_reserved_size(min_grain) if size < min_reserved_size(min_grain)

      # If we are here, align == :keep_size
      (size + min_grain).ceil(min_grain)
    end

  protected

    def internal_state
      instance_variables.sort.map { |v| instance_variable_get(v) }
    end

    def size_for(field)
      return disk_size if field == :current
      min_valid_disk_size(field)
    end

    def min_reserved_size(min_grain)
      min_grain * 2
    end
  end
end
