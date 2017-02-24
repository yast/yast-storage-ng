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
require "y2storage/secret_attributes"

module Y2Storage
  # Class to represent a planned volume (partition or logical volume) and
  # its constraints
  #
  class ProposedLv
    include SecretAttributes

    # @return [String] mount point for this volume. This might be a real mount
    # point ("/", "/boot", "/home") or a pseudo mount point like "swap".
    attr_accessor :mount_point
    # @return [::Storage::FsType] the type of filesystem this volume should
    # get, like ::Storage::FsType_BTRFS or ::Storage::FsType_SWAP. A value of
    # nil means the volume will not be formatted.
    attr_accessor :filesystem_type
    # @return [DiskSize] definitive size of the volume
    attr_accessor :disk_size
    # @return [DiskSize] maximum acceptable size
    attr_accessor :max_disk_size
    # @return [Float] factor used to distribute the extra space between
    # volumes
    attr_accessor :weight
    # @return [String] name to use if the volume is placed in LVM
    attr_accessor :logical_volume_name
    # @return [String] label to enforce in the filesystem
    attr_accessor :label
    # @return [String] UUID to enforce in the filesystem
    attr_accessor :uuid
    # @!attribute encryption_password
    #   @return [String, nil] password used to encrypt the volume. If is nil, it
    #   means the volume will not be encrypted
    secret_attr :encryption_password

    TO_STRING_ATTRS = [:mount_point, :filesystem_type, :disk_size]

    alias_method :max, :max_disk_size
    alias_method :max=, :max_disk_size=

    # Constructor.
    #
    # @param mount_point [string] @see #mount_point
    # @param filesystem_type [::Storage::FsType] @see #filesystem_type
    def initialize(volume: nil, target: nil)
      @mount_point     = nil
      @filesystem_type = nil
      @disk_size       = DiskSize.zero
      @max_disk_size   = DiskSize.unlimited
      @label           = nil
      @uuid            = nil
      @weight          = 0
      @logical_volume_name = nil

      copy_volume_values(volume, target) if volume

      return unless @mount_point
      @logical_volume_name = @mount_point == "/" ? "root" : @mount_point.sub(%r{^/}, "")
    end

    # FIXME it is duplicated in ProposedPartition
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
      "#<ProposedLv " + attrs.join(", ") + ">"
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

    # Checks whether the volume will be encrypted
    #
    # @return [Boolean]
    def encrypt?
      !encryption_password.nil?
    end

    
    # FIXME

    def self.disk_size(lvs, rounding: nil)
      rounding ||= DiskSize.new(1)
      lvs.reduce(DiskSize.zero) do |sum, lv| 
        sum + lv.disk_size.ceil(rounding)
      end
    end

    # Total sum of all current max sizes of volumes
    #
    # If the optional argument "rounding" is used, the size of every volume will
    # be rounded up. # @see DiskSize#ceil
    #
    # @param rounding [DiskSize, nil]
    # @return [DiskSize]
    def self.max_disk_size(lvs, rounding: nil)
      rounding ||= DiskSize.new(1)
      lvs.reduce(DiskSize.zero) { |sum, lv| sum + lv.max_disk_size.ceil(rounding) }
    end

    # Total sum of all current sizes of volumes
    #
    # @return [DiskSize] sum of sizes in @volumes
    def self.total_disk_size(lvs)
      lvs.reduce(DiskSize.zero) { |sum, lv| sum + lv.disk_size }
    end

    # Total sum of all weights of volumes
    #
    # @return [Float]
    def self.total_weight(lvs)
      lvs.reduce(0.0) { |sum, lv| sum + lv.weight }
    end

  protected

    def internal_state
      instance_variables.sort.map { |v| instance_variable_get(v) }
    end
  end
end
