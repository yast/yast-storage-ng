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

Yast.import "ProductFeatures"

module Y2Storage
  #
  # User-configurable settings for the storage proposal.
  # Those are settings the user can change in the UI.
  #
  class ProposalUserSettings
    include Yast::Logger
    include SecretAttributes

    attr_accessor :use_lvm
    attr_accessor :root_filesystem_type, :use_snapshots
    attr_accessor :use_separate_home, :home_filesystem_type
    attr_accessor :enlarge_swap_for_suspend
    attr_accessor :root_device, :candidate_devices
    secret_attr   :encryption_password

    def initialize
      @use_lvm                  = false
      self.encryption_password  = nil
      @root_filesystem_type     = ::Storage::FsType_BTRFS
      @use_snapshots            = true
      @use_separate_home        = true
      @home_filesystem_type     = ::Storage::FsType_XFS
      @enlarge_swap_for_suspend = false
    end

    def use_encryption
      !encryption_password.nil?
    end
  end

  # Per-product settings for the storage proposal.
  # Those settings are read from /control.xml on the installation media.
  # The user can directly override the part inherited from UserSettings.
  #
  class ProposalSettings < ProposalUserSettings
    attr_accessor :root_base_disk_size
    attr_accessor :root_max_disk_size
    attr_accessor :root_space_percent
    attr_accessor :btrfs_increase_percentage
    attr_accessor :min_size_to_use_separate_home
    attr_accessor :btrfs_default_subvolume
    attr_accessor :root_subvolume_read_only
    attr_accessor :home_min_disk_size
    attr_accessor :home_max_disk_size

    PRODUCT_SECTION = "partitioning"
    private_constant :PRODUCT_SECTION

    def initialize
      super
      # Default values taken from SLE-12-SP1
      @root_base_disk_size           = DiskSize.GiB(3)
      @root_max_disk_size            = DiskSize.GiB(10)
      @root_space_percent            = 40
      @min_size_to_use_separate_home = DiskSize.GiB(5)
      @btrfs_increase_percentage     = 300.0
      @btrfs_default_subvolume       = "@"
      @root_subvolume_read_only      = false

      # Not yet in control.xml
      @home_min_disk_size            = DiskSize.GiB(10)
      @home_max_disk_size            = DiskSize.unlimited
    end

    # Overrides all the settings with values read from the YaST product features
    # (i.e. values in /control.xml).
    #
    # Settings omitted in the product features are not modified. For backwards
    # compatibility reasons, features with a value of zero are also ignored.
    #
    # Calling this method modifies the object
    def read_product_features!
      set_from_boolean_feature(:use_lvm, :proposal_lvm)
      set_from_boolean_feature(:use_separate_home, :try_separate_home)
      set_from_boolean_feature(:use_snapshots, :proposal_snapshots)
      set_from_boolean_feature(:enlarge_swap_for_suspend, :swap_for_suspend)
      set_from_boolean_feature(:root_subvolume_read_only, :root_subvolume_read_only)

      set_from_size_feature(:root_base_disk_size, :root_base_size)
      set_from_size_feature(:root_max_disk_size, :root_max_size)
      set_from_size_feature(:home_max_disk_size, :vm_home_max_size)
      set_from_size_feature(:min_size_to_use_separate_home, :limit_try_home)

      set_from_integer_feature(:root_space_percent, :root_space_percent)
      set_from_integer_feature(:btrfs_increase_percentage, :btrfs_increase_percentage)

      set_from_string_feature(:btrfs_default_subvolume, :btrfs_default_subvolume)
    end

    # New object initialized according to the YaST product features
    # (i.e. /control.xml)
    #
    # @return [ProposalSettings]
    def self.new_for_current_product
      settings = new
      settings.read_product_features!
      settings
    end

    def to_s
      text = "Storage ProposalSettings\n" \
        "  use_lvm: #{use_lvm}\n" \
        "  root_filesystem_type: #{root_filesystem_type}\n" \
        "  use_snapshots: #{use_snapshots}\n" \
        "  use_separate_home: #{use_separate_home}\n" \
        "  home_filesystem_type: #{home_filesystem_type}\n" \
        "  enlarge_swap_for_suspend: #{enlarge_swap_for_suspend}\n" \
        "  root_device: #{root_device}\n" \
        "  candidate_devices: #{candidate_devices}\n" \
        "  root_base_disk_size: #{root_base_disk_size}\n" \
        "  root_max_disk_size: #{root_max_disk_size}\n" \
        "  root_space_percent: #{root_space_percent}\n" \
        "  btrfs_increase_percentage: #{btrfs_increase_percentage}\n" \
        "  min_size_to_use_separate_home: #{min_size_to_use_separate_home}\n" \
        "  btrfs_default_subvolume: #{btrfs_default_subvolume}\n" \
        "  root_subvolume_read_only: #{root_subvolume_read_only}\n" \
        "  home_min_disk_size: #{home_min_disk_size}\n" \
        "  home_max_disk_size: #{home_max_disk_size}"
    end

  protected

    # Value of a product feature in the partitioning section
    #
    # @param name [#to_s] name of the feature
    # @param type [#to_s] type of the feature
    # @return [Object] value of the feature, nil if no value is specified
    def product_feature(name, type)
      # GetBooleanFeature cannot distinguish between missing and false
      return nil unless Yast::ProductFeatures.GetSection(PRODUCT_SECTION).key?(name.to_s)

      Yast::ProductFeatures.send(:"Get#{type.to_s.capitalize}Feature", PRODUCT_SECTION, name.to_s)
    end

    def set_from_boolean_feature(attr, feature)
      value = product_feature(feature, :boolean)
      send(:"#{attr}=", value) unless value.nil?
    end

    def set_from_string_feature(attr, feature)
      value = product_feature(feature, :string)
      send(:"#{attr}=", value) unless value.nil?
    end

    def set_from_size_feature(attr, feature)
      value = product_feature(feature, :string)
      return unless value

      begin
        value = DiskSize.parse(value, legacy_units: true)
      rescue ArgumentError
        value = nil
      end
      send(:"#{attr}=", value) if value && value > DiskSize.zero
    end

    def set_from_integer_feature(attr, feature)
      value = product_feature(feature, :integer)
      send(:"#{attr}=", value) if value && value >= 0
    end
  end
end
