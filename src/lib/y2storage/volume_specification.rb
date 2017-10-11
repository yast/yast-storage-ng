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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "y2storage/partitioning_features"
require "y2storage/subvol_specification"

module Y2Storage
  # Helper class to represent a volume specification as defined in control.xml
  class VolumeSpecification
    include PartitioningFeatures

    # @return [String] directory where the volume will be mounted in the system
    attr_accessor :mount_point

    # @return [Boolean] whether this volume should be created or skipped
    attr_accessor :proposed

    # @return [Boolean] whether the user can change the proposed setting in the UI
    attr_accessor :proposed_configurable

    # @return [List<Filesystems::Type>] acceptable filesystem types
    attr_accessor :fs_types

    # @return [Filesystems::Type] default file system type to format the volume
    attr_accessor :fs_type

    # @return [DiskSize] initial size to use in the first proposal attempt
    attr_accessor :desired_size

    # @return [DiskSize] initial size to use in the second proposal attempt
    attr_accessor :min_size

    # @return [DiskSize] maximum size to assign to the volume
    attr_accessor :max_size

    # @return [DiskSize] when LVM is used, this option can be used to override
    #   the value at max_size
    attr_accessor :max_size_lvm

    # @return [Numeric] value used to distribute the extra space (after assigning
    #   the initial ones) among the volumes
    attr_accessor :weight

    # @return [Boolean] whether the initial and max sizes of each attempt should be
    #   adjusted based in the RAM size
    attr_accessor :adjust_by_ram

    # @return [Boolean] whether the user can change the adjust_by_ram setting in the UI
    attr_accessor :adjust_by_ram_configurable

    # @return [String] mount point of another volume
    attr_accessor :fallback_for_min_size

    # @return [String] mount point of another volume
    attr_accessor :fallback_for_desired_size

    # @return [String] mount point of another volume
    attr_accessor :fallback_for_max_size

    # @return [String] mount point of another volume
    attr_accessor :fallback_for_max_size_lvm

    # @return [String] mount point of another volume
    attr_accessor :fallback_for_weight

    # @return [Boolean] whether snapshots should be activated
    attr_accessor :snapshots

    # @return [Boolean] whether the user can change the snapshots setting in the UI
    attr_accessor :snapshots_configurable

    # @return [DiskSize] the initial and maximum sizes for the volume will be
    #   increased according if snapshots are being used. If it's a number, it
    #   will be used as a percentage of the original sizes.
    attr_accessor :snapshots_size

    # @return [Array<SubvolSpecification>] list of specifications (usually read
    #   from the control file) that will be used to plan the Btrfs subvolumes
    attr_accessor :subvolumes

    # @return [String] default btrfs subvolume path
    attr_accessor :btrfs_default_subvolume

    # @return [Numeric] order to disable volumes if needed to make the initial proposal
    attr_accessor :disable_order

    alias_method :proposed?, :proposed
    alias_method :proposed_configurable?, :proposed_configurable
    alias_method :adjust_by_ram?, :adjust_by_ram
    alias_method :adjust_by_ram_configurable?, :adjust_by_ram_configurable
    alias_method :snapshots?, :snapshots
    alias_method :snapshots_configurable?, :snapshots_configurable

    # Constructor
    # @param volume_features [Hash] features for a volume
    def initialize(volume_features)
      apply_defaults
      load_features(volume_features)
    end

  private

    def apply_defaults
      @max_size ||= DiskSize.unlimited
    end

    # For some features (i.e., fs_types and subvolumes) fallback values could be applied

    def load_features(volume_features)
      {
        mount_point:                :string,
        proposed:                   :boolean,
        proposed_configurable:      :boolean,
        fs_types:                   :list,
        fs_type:                    :string,
        adjust_by_ram:              :boolean,
        adjust_by_ram_configurable: :boolean,
        fallback_for_min_size:      :string,
        fallback_for_desired_size:  :string,
        fallback_for_max_size:      :string,
        fallback_for_max_size_lvm:  :string,
        fallback_for_weight:        :string,
        snapshots:                  :boolean,
        snapshots_configurable:     :boolean,
        btrfs_default_subvolume:    :string,
        desired_size:               :size,
        min_size:                   :size,
        max_size:                   :size,
        max_size_lvm:               :size,
        # FIXME: allow snapshots_size to be both: a percentage and a disk size
        snapshots_size:             :size,
        weight:                     :integer,
        disable_order:              :integer,
        subvolumes:                 :subvolumes
      }.each do |feature, type|
        type = nil if [:string, :boolean, :list].include?(type)
        loader = type.nil? ? "load_feature" : "load_#{type}_feature"
        send(loader, feature, source: volume_features)
      end

      apply_fallbacks
    end

    def fs_types=(types)
      @fs_types = types.map { |t| validated_fs_type(t) }
    end

    def fs_type=(type)
      @fs_type = validated_fs_type(type)
    end

    def validated_fs_type(type)
      raise(ArgumentError, "Filesystem cannot be nil") unless type
      Filesystems::Type.find(type.downcase.to_sym)
    end

    def root?
      mount_point && mount_point == "/"
    end

    def apply_fallbacks
      apply_subvolumes_fallback
      apply_fs_types_fallback
    end

    # If subvolumes is missing, a hard-coded list is used for root. If the section is
    # there but empty, no subvolumes are created.
    def apply_subvolumes_fallback
      return unless subvolumes.nil?
      @subvolumes = root? ? SubvolSpecification.fallback_list : []
    end

    # If fs_types is missing or is empty, a hard-coded list is used
    def apply_fs_types_fallback
      return if fs_types && !fs_types.empty?

      types = case mount_point
      when "/"
        Filesystems::Type.root_filesystems
      when "/home"
        Filesystems::Type.home_filesystems
      else
        [fs_type].compact
      end

      @fs_types = types
    end
  end
end
