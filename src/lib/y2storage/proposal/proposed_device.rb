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
  # Class to represent a proposed device (partition or logical volume) and
  # its constraints
  #
  class ProposedDevice
    include SecretAttributes

    # @return [String] mount point for this device. This might be a real mount
    # point ("/", "/boot", "/home") or a pseudo mount point like "swap".
    attr_accessor :mount_point
    # @return [::Storage::FsType] the type of filesystem this volume should
    # get, like ::Storage::FsType_BTRFS or ::Storage::FsType_SWAP. A value of
    # nil means the volume will not be formatted.
    attr_accessor :filesystem_type
    # @return [String] label to enforce in the filesystem
    attr_accessor :label
    # @return [String] UUID to enforce in the filesystem
    attr_accessor :uuid
    # @return [DiskSize] size of the proposed device
    attr_accessor :disk_size
    # @return [DiskSize] maximum acceptable size
    attr_accessor :max_disk_size
    # @return [Float] factor used to distribute the extra space between
    # proposed devices
    attr_accessor :weight
    # @!attribute encryption_password
    #   @return [String, nil] password used to encrypt the device. If is nil, it
    #   means the proposed device will not be encrypted
    secret_attr :encryption_password

    TO_STRING_ATTRS = [:mount_point, :filesystem_type, :disk_size, :max_disk_size]

    alias_method :max, :max_disk_size
    alias_method :max=, :max_disk_size=

    # Constructor.
    #
    # @param volume [PlannedVolume]
    # @param target [Symbol] size to allocate (:desired, :min)
    def initialize(volume: nil, target: nil)
      @mount_point      = nil
      @filesystem_type  = nil
      @label            = nil
      @uuid             = nil
      @disk_size        = DiskSize.zero
      @max_disk_size    = DiskSize.unlimited
      @weight = 0
      copy_volume_values(volume, target) if volume
    end

    def to_s
      attrs = TO_STRING_ATTRS.map do |attr|
        value = send(attr)
        value = "nil" if value.nil?
        "#{attr}=#{value}"
      end
      "#<#{self.class} " + attrs.join(", ") + ">"
    end

    # Create a filesystem for the proposed device on the specified
    # partition and set its mount point. Do nothing if #filesystem_type
    # is not set.
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

    # Checks whether the proposed device will be encrypted
    #
    # @return [Boolean]
    def encrypt?
      !encryption_password.nil?
    end

    # Total sum of all sizes of proposed partitions
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
    def self.disk_size(proposed_devices, rounding: nil)
      rounding ||= DiskSize.new(1)
      proposed_devices.reduce(DiskSize.zero) do |sum, device|
        sum + device.disk_size.ceil(rounding)
      end
    end

    # Total sum of all current max sizes of volumes
    #
    # If the optional argument "rounding" is used, the size of every volume will
    # be rounded up. # @see DiskSize#ceil
    #
    # @param rounding [DiskSize, nil]
    # @return [DiskSize]
    def self.max_disk_size(proposed_devices, rounding: nil)
      rounding ||= DiskSize.new(1)
      proposed_devices.reduce(DiskSize.zero) do |sum, device|
        sum + device.max_disk_size.ceil(rounding)
      end
    end

  protected

    def internal_state
      instance_variables.sort.map { |v| instance_variable_get(v) }
    end

    def copy_volume_values(volume, target)
      instance_variables.each do |inst_variable|
        volume_method = inst_variable.to_s.sub("@", "")
        if volume.respond_to?(volume_method)
          instance_variable_set(inst_variable, volume.send(volume_method))
        end
      end
      @disk_size = volume.min_valid_disk_size(target)
    end
  end
end
