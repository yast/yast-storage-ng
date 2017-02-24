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
require "y2storage/disk_size"
require "y2storage/secret_attributes"

module Y2Storage
  # Class to represent a planned volume (partition or logical volume) and
  # its constraints
  #
  class ProposedPartition
    include SecretAttributes

    # @return [String] mount point for this volume. This might be a real mount
    # point ("/", "/boot", "/home") or a pseudo mount point like "swap".
    attr_accessor :mount_point
    # @return [::Storage::FsType] the type of filesystem this volume should
    # get, like ::Storage::FsType_BTRFS or ::Storage::FsType_SWAP. A value of
    # nil means the volume will not be formatted.
    attr_accessor :filesystem_type
    # @return [::Storage::IdNum] id of the partition in a ms-dos style
    # partition table. If nil, the final id is expected to be inferred from
    # the filesystem type.
    attr_accessor :partition_id
    # @return [String] device name of the disk in which the volume has to be
    # located. If nil, the volume can be allocated in any disk.
    attr_accessor :disk
    # @return [DiskSize] definitive size of the volume
    attr_accessor :disk_size
    # @return [DiskSize] maximum acceptable size
    attr_accessor :max_disk_size
    # @return [Float] factor used to distribute the extra space between
    # volumes
    attr_accessor :weight
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
    # @!attribute encryption_password
    #   @return [String, nil] password used to encrypt the volume. If is nil, it
    #   means the volume will not be encrypted
    secret_attr :encryption_password

    TO_STRING_ATTRS = [:mount_point, :disk, :disk_size, :max_start_offset]

    alias_method :max, :max_disk_size
    alias_method :max=, :max_disk_size=

    # Constructor.
    #
    # @param mount_point [string] @see #mount_point
    # @param filesystem_type [::Storage::FsType] @see #filesystem_type
    def initialize(volume: nil, target: nil)
      @mount_point      = nil
      @filesystem_type  = nil
      @partition_id     = nil
      @disk             = nil
      @disk_size        = DiskSize.zero
      @max_disk_size    = DiskSize.unlimited
      @max_start_offset = nil
      @align            = nil
      @bootable         = nil
      @label            = nil
      @uuid             = nil
      @weight           = 0

      copy_volume_values(volume, target) if volume
    end

    # FIXME it is duplicated in ProposedLv
    def copy_volume_values(volume, target)
      instance_variables.each do |inst_variable|
        volume_method = inst_variable.to_s.sub("@", "")
        if volume.respond_to?(volume_method)
          instance_variable_set(inst_variable, volume.send(volume_method))
        end
      end
      @disk_size = volume.min_valid_disk_size(target)
    end


    def to_s
      attrs = TO_STRING_ATTRS.map do |attr|
        value = send(attr)
        value = "nil" if value.nil?
        "#{attr}=#{value}"
      end
      "#<ProposedPartition " + attrs.join(", ") + ">"
    end

    # Create a filesystem for the volume on the specified partition and set its
    # mount point. Do nothing if #filesystem_type is not set.
    #
    # @param partition [::Storage::Partition]
    #
    # @return [::Storage::BlkFilesystem] filesystem
    def create_filesystem(partition)
      return nil unless filesystem_type
      filesystem = partition.create_filesystem(filesystem_type)
      filesystem.add_mountpoint(mount_point) if mount_point && !mount_point.empty?
      filesystem.label = label if label
      filesystem.uuid = uuid if uuid
      filesystem
    end

    def ==(other)
      other.class == self.class && other.internal_state == internal_state
    end

    # Checks whether the volume represents an LVM physical volume
    #
    # @return [Boolean]
    def lvm_pv?
      partition_id == Storage::ID_LVM
    end

    # Checks whether the volume will be encrypted
    #
    # @return [Boolean]
    def encrypt?
      !encryption_password.nil?
    end

    # FIXME

    # Total sum of all desired or min sizes of volumes (according to #target)
    #
    # This tries to avoid an 'unlimited' result:
    # If a the desired size of any volume is 'unlimited',
    # its minimum size is taken instead. This gives a more useful sum in the
    # very common case that any volume has an 'unlimited' desired size.
    #
    # If the optional argument "rounding" is used, the size of every volume will
    # be rounded up. # @see DiskSize#ceil
    #
    # @param rounding [DiskSize, nil]
    # @return [DiskSize] sum of desired/min sizes in @volumes
    def self.disk_size(partitions, rounding: nil)
      rounding ||= DiskSize.new(1)
      partitions.reduce(DiskSize.zero) do |sum, partition| 
        sum + partition.disk_size.ceil(rounding)
      end
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
    def self.enforced_last(partitions, size_to_fill, min_grain)
      rounded_up = disk_size(partitions, rounding: min_grain)
      # There is enough space to fit with any order
      return nil if size_to_fill >= rounded_up

      missing = rounded_up - size_to_fill
      # It's impossible to fit
      return nil if missing >= min_grain

      partitions.detect do |partition|
        target_size = partition.disk_size
        target_size.ceil(min_grain) - missing >= target_size
      end
    end

    # Total sum of all current max sizes of volumes
    #
    # If the optional argument "rounding" is used, the size of every volume will
    # be rounded up. # @see DiskSize#ceil
    #
    # @param rounding [DiskSize, nil]
    # @return [DiskSize]
    def self.max_disk_size(partitions, rounding: nil)
      rounding ||= DiskSize.new(1)
      partitions.reduce(DiskSize.zero) do |sum, partition|
        sum + partition.max_disk_size.ceil(rounding)
      end
    end

    # Total sum of all current sizes of volumes
    #
    # @return [DiskSize] sum of sizes in @volumes
    def self.total_disk_size(partitions)
      partitions.reduce(DiskSize.zero) { |sum, partition| sum + partition.disk_size }
    end

    # Total sum of all weights of volumes
    #
    # @return [Float]
    def self.total_weight(partitions)
      partitions.reduce(0.0) { |sum, partition| sum + partition.weight }
    end

  protected

    def internal_state
      instance_variables.sort.map { |v| instance_variable_get(v) }
    end
  end
end
