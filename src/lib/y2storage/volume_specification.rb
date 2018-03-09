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
require "y2storage/volume_specification"

module Y2Storage
  # Helper class to represent a volume specification as defined in control.xml
  class VolumeSpecification
    include PartitioningFeatures

    # @return [PartitionId] when the volume needs to be a partition with a specific id
    attr_accessor :partition_id

    # @return [String] directory where the volume will be mounted in the system
    attr_accessor :mount_point

    # @return [Boolean] whether this volume should be created or skipped
    attr_accessor :proposed

    # @return [Boolean] whether the user can change the proposed setting in the UI
    attr_accessor :proposed_configurable

    # @return [Filesystems::Type] default file system type to format the volume
    attr_reader :fs_type

    # @return [List<Filesystems::Type>] acceptable filesystem types
    attr_reader :fs_types

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

    # @note snaphots_size and snapshots_percentage are exclusive in the control file.
    # @return [DiskSize] the initial and maximum sizes for the volume will be
    #   increased according if snapshots are being used.
    attr_accessor :snapshots_size

    # @note snaphots_size and snapshots_percentage are exclusive in the control file.
    # @return [Integer] the initial and maximum sizes for the volume will be
    #   increased according if snapshots are being used. It represents a percentage
    #   of the original sizes.
    attr_accessor :snapshots_percentage

    # @return [Array<SubvolSpecification>] list of specifications (usually read
    #   from the control file) that will be used to plan the Btrfs subvolumes
    attr_accessor :subvolumes

    # @return [String] default btrfs subvolume path
    attr_accessor :btrfs_default_subvolume

    # @return [Boolean] whether the volume should be mounted as read-only
    attr_accessor :btrfs_read_only

    # @return [Numeric] order to disable volumes if needed to make the initial proposal
    attr_accessor :disable_order

    alias_method :proposed?, :proposed
    alias_method :proposed_configurable?, :proposed_configurable
    alias_method :adjust_by_ram?, :adjust_by_ram
    alias_method :adjust_by_ram_configurable?, :adjust_by_ram_configurable
    alias_method :snapshots?, :snapshots
    alias_method :snapshots_configurable?, :snapshots_configurable

    class << self
      # Returns the volume specification for the given mount point
      #
      # This is a convenience method to avoid other classes having to know about
      # {VolumeSpecificationBuilder}.
      #
      # @param mount_point [String] Volume's mount point
      # @return [VolumeSpecification,nil] Volume specification or nil if not found
      def for(mount_point)
        VolumeSpecificationBuilder.new.for(mount_point)
      end
    end

    # Constructor
    # @param volume_features [Hash] features for a volume
    def initialize(volume_features)
      apply_defaults
      load_features(volume_features)
    end

    # @see #fs_type
    #
    # @param type [Filesystems::Type, String]
    def fs_type=(type)
      @fs_type = validated_fs_type(type)
    end

    # @param types [Array<String>, String] an array of filesystem types or a
    #   list of comma-separated ones
    def fs_types=(types)
      types = types.strip.split(/\s*,\s*/) if types.is_a?(String)
      @fs_types = types.map { |t| validated_fs_type(t) }
    end

    # Whether the user can configure some aspect of the volume
    #
    # Returns false if there is no chance for the volume to be proposed or if
    # none of its attributes can be configured by the user.
    #
    # @return [Boolean]
    def configurable?
      return false if !proposed && !proposed_configurable?

      proposed_configurable? ||
        adjust_by_ram_configurable? ||
        snapshots_configurable? ||
        fs_type_configurable?
    end

    # Checks whether #fs_type can be configured by the user
    #
    # @return [Boolean]
    def fs_type_configurable?
      fs_types.size > 1
    end

    # Whether the resulting device will be mounted as root
    #
    # @return [Boolean]
    def root?
      mount_point && mount_point == "/"
    end

    # Whether the resulting device will be mounted as swap
    #
    # @return [Boolean]
    def swap?
      mount_point && mount_point == "swap"
    end

  private

    FEATURES = {
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
      btrfs_read_only:            :boolean,
      desired_size:               :size,
      min_size:                   :size,
      max_size:                   :size,
      max_size_lvm:               :size,
      snapshots_size:             :size,
      snapshots_percentage:       :integer,
      weight:                     :integer,
      disable_order:              :integer,
      subvolumes:                 :subvolumes
    }.freeze

    def apply_defaults
      @proposed                   = true
      @proposed_configurable      = false
      @desired_size               = DiskSize.zero
      @min_size                   = DiskSize.zero
      @max_size                   = DiskSize.unlimited
      @max_size_lvm               = DiskSize.zero
      @weight                     = 0
      @adjust_by_ram              = false
      @adjust_by_ram_configurable = false
      @snapshots                  = false
      @snapshots_configurable     = false
      @snapshots_size             = DiskSize.zero
      @snapshots_percentage       = 0
      @fs_types                   = []
    end

    # For some features (i.e., fs_types and subvolumes) fallback values could be applied
    # @param volume_features [Hash] features for a volume
    def load_features(volume_features)
      FEATURES.each do |feature, type|
        type = nil if [:string, :boolean, :list].include?(type)
        loader = type.nil? ? "load_feature" : "load_#{type}_feature"
        send(loader, feature, source: volume_features)
      end

      apply_fallbacks
    end

    def validated_fs_type(type)
      raise(ArgumentError, "Filesystem cannot be nil") unless type
      return type if type.is_a?(Filesystems::Type)
      Filesystems::Type.find(type.downcase.to_sym)
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

    # If fs_types is empty, a hard-coded list is used for root and home.
    #
    # @note It always includes fs_type in the list.
    def apply_fs_types_fallback
      if fs_types.empty?
        if mount_point == "/"
          @fs_types = Filesystems::Type.root_filesystems
        end
        if mount_point == "/home"
          @fs_types = Filesystems::Type.home_filesystems
        end
      end

      include_fs_type
    end

    # Adds fs_type to the list of possible filesystems
    def include_fs_type
      @fs_types.unshift(fs_type) if fs_type && !fs_types.include?(fs_type)
    end
  end
end
