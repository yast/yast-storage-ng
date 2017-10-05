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

    attr_accessor :mount_point
    attr_accessor :proposed
    attr_accessor :proposed_configurable
    attr_accessor :fs_types
    attr_accessor :fs_type
    attr_accessor :desired_size
    attr_accessor :min_size
    attr_accessor :max_size
    attr_accessor :max_size_lvm
    attr_accessor :weight
    attr_accessor :adjust_by_ram
    attr_accessor :adjust_by_ram_configurable
    attr_accessor :fallback_for_min_size
    attr_accessor :fallback_for_max_size
    attr_accessor :fallback_for_max_size_lvm
    attr_accessor :fallback_for_weight
    attr_accessor :snapshots
    attr_accessor :snapshots_configurable
    attr_accessor :snapshots_size
    attr_accessor :subvolumes
    attr_accessor :btrfs_default_subvolume
    attr_accessor :disable_order

    alias_method :proposed?, :proposed
    alias_method :proposed_configurable?, :proposed_configurable
    alias_method :adjust_by_ram?, :adjust_by_ram
    alias_method :adjust_by_ram_configurable?, :adjust_by_ram_configurable
    alias_method :snapshots?, :snapshots
    alias_method :snapshots_configurable?, :snapshots_configurable

    def initialize(volume_features)
      @volume_features = volume_features
      apply_defaults
      load_features
    end

  private

    attr_reader :volume_features

    def apply_defaults
      @fs_types   ||= []
      @subvolumes ||= []
    end

    def load_features
      {
        mount_point:                :string,
        proposed:                   :boolean,
        proposed_configurable:      :boolean,
        fs_types:                   :list,
        fs_type:                    :string,
        adjust_by_ram:              :boolean,
        adjust_by_ram_configurable: :boolean,
        fallback_for_min_size:      :string,
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
        snapshots_size:             :size,
        weight:                     :integer,
        disable_order:              :integer,
        subvolumes:                 :subvolumes
      }.each do |feature, type|
        type = nil if [:string, :boolean, :list].include?(type)
        loader = type.nil? ? "load_feature" : "load_#{type}_feature"
        send(loader, feature, source: volume_features)
      end

      apply_fallback_subvolumes if root? && subvolumes.empty?
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

    def apply_fallback_subvolumes
      self.subvolumes = SubvolSpecification.fallback_list
    end
  end
end
