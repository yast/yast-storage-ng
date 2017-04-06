#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2017] SUSE LLC
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
require "y2storage/planned_subvol"
require "y2storage/secret_attributes"

module Y2Storage
  # Class to represent a planned volume (partition or logical volume) and
  # its constraints
  #
  class PlannedVolume
    include SecretAttributes

    # @return [String] mount point for this volume. This might be a real mount
    # point ("/", "/boot", "/home") or a pseudo mount point like "swap".
    attr_accessor :mount_point
    # @return [Filesystems::Type] the type of filesystem this volume should
    # get, like Filesystems::Type::BTRFS or Filesystems::Type::SWAP. A value of
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
    # @return [Boolean] whether the volume must be created as a plain
    # partition. If so, that volume cannot live into LVM and cannot be
    # encrypted.
    attr_accessor :plain_partition
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
    # @!attribute subvolumes
    #   @return Array[PlannedSubvolume] Btrfs subvolumes
    attr_accessor :subvolumes
    # @!attribute default_subvolume
    # @return [String] Parent for all Btrfs subvolumes (typically "@")
    attr_accessor :default_subvolume
    # @!attribute encryption_password
    #   @return [String, nil] password used to encrypt the volume. If is nil, it
    #   means the volume will not be encrypted
    secret_attr :encryption_password

    TO_STRING_ATTRS = [:mount_point, :reuse, :min_disk_size, :max_disk_size,
                       :desired_disk_size, :disk, :max_start_offset, :subvolumes]

    alias_method :desired, :desired_disk_size
    alias_method :min, :min_disk_size
    alias_method :max, :max_disk_size
    alias_method :desired=, :desired_disk_size=
    alias_method :min=, :min_disk_size=
    alias_method :max=, :max_disk_size=
    alias_method :plain_partition?, :plain_partition

    # Constructor.
    #
    # @param mount_point [string] @see #mount_point
    # @param filesystem_type [Filesystems::Type] @see #filesystem_type
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
      @plain_partition = true
      @logical_volume_name = nil
      @subvolumes          = nil
      @default_subvolume   = nil

      return unless @mount_point && @mount_point.start_with?("/")
      return if @mount_point && @mount_point.start_with?("/boot")

      @plain_partition = false
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
    # @param partition [Partition]
    #
    # @return [Filesystems::BlkFilesystem] filesystem
    def create_filesystem(partition)
      return nil unless filesystem_type
      filesystem = partition.create_blk_filesystem(filesystem_type)
      filesystem.mountpoint = mount_point if mount_point && !mount_point.empty?
      filesystem.label = label if label
      filesystem.uuid = uuid if uuid
      filesystem
    end

    # Create subvolumes on this volume after the filesystem is created
    # if this is a btrfs root filesystem.
    #
    # @param filesystem [::Storage::Filesystem]
    # @param other_mount_points [Array<String>]
    #
    # @return nil
    #
    def create_subvolumes(filesystem, other_mount_points)
      return unless filesystem.supports_btrfs_subvolumes?
      return unless subvolumes?
      parent_subvol = get_parent_subvol(filesystem)
      prefix = filesystem.mountpoint
      prefix += "/" unless prefix == "/"
      @subvolumes.each do |planned_subvol|
        # Notice that subvolumes not matching the current architecture are
        # already removed
        next if PlannedVolume.shadows?(prefix + planned_subvol.path, other_mount_points)
        planned_subvol.create_subvol(parent_subvol, @default_subvolume, prefix)
      end
      nil
    end

    # Get the parent subvolume for all others on Btrfs 'filesystem':
    #
    # If a default subvolume is configured (in control.xml), create it; if not,
    # use the toplevel subvolume that is implicitly created by mkfs.btrfs.
    #
    # @param filesystem [::Storage::Filesystem]
    #
    # @return [::Storage::BtrfsSubvolume]
    #
    def get_parent_subvol(filesystem)
      # The toplevel subvolume is implicitly created by mkfs.btrfs.
      # It does not have a name, and its subvolume ID is always 5.
      parent = filesystem.top_level_btrfs_subvolume
      if @default_subvolume && !@default_subvolume.empty?
        # If the "@" subvolume is specified in control.xml, this must be
        # created first, and it will be the parent of all the other
        # subvolumes. Otherwise, the toplevel subvolume is their direct parent.
        # Notice that this "@" subvolume does not show up in "btrfs subvolume
        # list".
        parent = parent.create_btrfs_subvolume(@default_subvolume)
      end
      parent
    end

    # Check if 'mount_point' shadows any of the mount points in
    # 'other_mount_points'.
    #
    # @param mount_point [String] mount point to check
    # @param other_mount_points [Array<String>]
    #
    # @return [Boolean]
    #
    def self.shadows?(mount_point, other_mount_points)
      return false if mount_point.nil? || other_mount_points.nil?
      # Just checking with start_with? is not sufficient:
      # "/bootinger/schlonz".start_with?("/boot") -> true
      # So append "/" to make sure only complete subpaths are compared:
      # "/bootinger/schlonz/".start_with?("/boot/") -> false
      # "/boot/schlonz/".start_with?("/boot/") -> true
      mount_point += "/"
      other_mount_points.any? do |other|
        next false if other.nil?
        mount_point.start_with?(other + "/")
      end
    end

    # Checks whether the volume represents an LVM physical volume
    #
    # @return [Boolean]
    def lvm_pv?
      partition_id && partition_id.is?(:lvm)
    end

    def ==(other)
      other.class == self.class && other.internal_state == internal_state
    end

    # Checks whether the volume will be encrypted
    #
    # @return [Boolean]
    def encrypt?
      !encryption_password.nil?
    end

    # Checks whether the filesystem type is Btrfs
    #
    # @return [Boolean]
    def btrfs?
      return false unless filesystem_type
      filesystem_type.is?(:btrfs)
    end

    # Checks whether the volume has any subvolumes
    #
    # @return [Boolean]
    def subvolumes?
      btrfs? && !subvolumes.nil? && !subvolumes.empty?
    end

  protected

    def internal_state
      instance_variables.sort.map { |v| instance_variable_get(v) }
    end
  end
end
