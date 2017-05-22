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
require "y2storage/subvol_specification"
require "y2storage/filesystems/type"

Yast.import "ProductFeatures"

module Y2Storage
  #
  # User-configurable settings for the storage proposal.
  # Those are settings the user can change in the UI.
  #
  class ProposalUserSettings
    include Yast::Logger
    include SecretAttributes

    VALID_DELETE_MODES = [:none, :all, :ondemand]
    private_constant :VALID_DELETE_MODES

    # @return [Boolean] whether to use LVM
    attr_accessor :use_lvm

    # @return [Filesystems::Type] type to use for the root filesystem
    attr_accessor :root_filesystem_type
    #
    # @return [Boolean] whether to enable snapshots (only if Btrfs is used)
    attr_accessor :use_snapshots

    # @return [Boolean] whether to propose separate partition/volume for /home
    attr_accessor :use_separate_home

    # @return [Filesystems::Type] type to use for the home filesystem, if a
    #   separate one is proposed
    attr_accessor :home_filesystem_type

    # @return [Boolean] whether to enlarge swap based on the RAM size, to ensure
    #   the classic suspend-to-ram works
    attr_accessor :enlarge_swap_for_suspend

    # @return [String] device name of the disk in which / must be placed. If set
    #   to nil, the proposal will try to find a good candidate
    attr_accessor :root_device

    # @return [Array<String>] device names of the disks that can be used for the
    #   installation. If nil, the proposal will try find suitable devices
    attr_accessor :candidate_devices

    # @!attribute encryption_password
    #   @return [String] password to use when creating new encryption devices
    secret_attr   :encryption_password

    # @return [Boolean] whether to resize Windows systems if needed
    attr_accessor :resize_windows

    # @return [Symbol] what to do regarding removal of existing partitions
    #   hosting a Windows system.
    #
    #   * :none Never delete a Windows partition.
    #   * :ondemand Delete Windows partitions as needed by the proposal.
    #   * :all Delete all Windows partitions, even if not needed.
    #
    #   @raise ArgumentError if any other value is assigned
    attr_accessor :windows_delete_mode

    # @return [Symbol] what to do regarding removal of existing Linux
    #   partitions. See {DiskAnalyzer} for the definition of "Linux partitions".
    #   @see #windows_delete_mode for the possible values and exceptions
    attr_accessor :linux_delete_mode

    # @return [Symbol] what to do regarding removal of existing partitions that
    #   don't fit in #windows_delete_mode or #linux_delete_mode.
    #   @see #windows_delete_mode for the possible values and exceptions
    attr_accessor :other_delete_mode

    def initialize
      @use_lvm                  = false
      self.encryption_password  = nil
      @root_filesystem_type     = Filesystems::Type::BTRFS
      @use_snapshots            = true
      @use_separate_home        = true
      @home_filesystem_type     = Filesystems::Type::XFS
      @enlarge_swap_for_suspend = false
      @resize_windows           = true
      @windows_delete_mode      = :ondemand
      @linux_delete_mode        = :ondemand
      @other_delete_mode        = :ondemand
    end

    def use_encryption
      !encryption_password.nil?
    end

    # Whether the settings disable deletion of a given type of partitions
    #
    # @see #windows_delete_mode
    # @see #linux_delete_mode
    # @see #other_delete_mode
    #
    # @param type [#to_s] :linux, :windows or :other
    # @return [Boolean]
    def delete_forbidden(type)
      send(:"#{type}_delete_mode") == :none
    end

    alias_method :delete_forbidden?, :delete_forbidden

    # Whether the settings enforce deletion of a given type of partitions
    #
    # @see #windows_delete_mode
    # @see #linux_delete_mode
    # @see #other_delete_mode
    #
    # @param type [#to_s] :linux, :windows or :other
    # @return [Boolean]
    def delete_forced(type)
      send(:"#{type}_delete_mode") == :all
    end

    alias_method :delete_forced?, :delete_forced

    alias_method :set_windows_delete_mode, :windows_delete_mode=
    private :set_windows_delete_mode
    def windows_delete_mode=(mode)
      set_windows_delete_mode(validated_delete_mode(mode))
    end

    alias_method :set_linux_delete_mode, :linux_delete_mode=
    private :set_linux_delete_mode
    def linux_delete_mode=(mode)
      set_linux_delete_mode(validated_delete_mode(mode))
    end

    alias_method :set_other_delete_mode, :other_delete_mode=
    private :set_other_delete_mode
    def other_delete_mode=(mode)
      set_other_delete_mode(validated_delete_mode(mode))
    end

  private

    def validated_delete_mode(mode)
      raise(ArgumentError, "Mode cannot be nil") unless mode
      result = mode.to_sym
      if !VALID_DELETE_MODES.include?(result)
        raise ArgumentError, "Invalid mode"
      end
      result
    end
  end

  # Per-product settings for the storage proposal.
  # Those settings are read from /control.xml on the installation media.
  # The user can directly override the part inherited from UserSettings.
  #
  class ProposalSettings < ProposalUserSettings
    attr_accessor :root_base_size
    attr_accessor :root_max_size
    attr_accessor :root_space_percent
    attr_accessor :btrfs_increase_percentage
    attr_accessor :min_size_to_use_separate_home
    attr_accessor :btrfs_default_subvolume
    attr_accessor :root_subvolume_read_only
    attr_accessor :home_min_size
    attr_accessor :home_max_size

    # @return [Array<SubvolSpecification>] list of specifications (usually read
    #   from the control file) that will be used to plan the Btrfs subvolumes of
    #   the root filesystem
    #   @see #planned_subvolumes
    attr_accessor :subvolumes

    PRODUCT_SECTION = "partitioning"
    private_constant :PRODUCT_SECTION

    def initialize
      super
      # Default values taken from SLE-12-SP1
      @root_base_size           = DiskSize.GiB(3)
      @root_max_size            = DiskSize.GiB(10)
      @root_space_percent            = 40
      @min_size_to_use_separate_home = DiskSize.GiB(5)
      @btrfs_increase_percentage     = 300.0
      @btrfs_default_subvolume       = "@"
      @root_subvolume_read_only      = false
      @subvolumes                    = SubvolSpecification.fallback_list

      # Not yet in control.xml
      @home_min_size            = DiskSize.GiB(10)
      @home_max_size            = DiskSize.unlimited
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

      set_from_size_feature(:root_base_size, :root_base_size)
      set_from_size_feature(:root_max_size, :root_max_size)
      set_from_size_feature(:home_max_size, :vm_home_max_size)
      set_from_size_feature(:min_size_to_use_separate_home, :limit_try_home)

      set_from_integer_feature(:root_space_percent, :root_space_percent)
      set_from_integer_feature(:btrfs_increase_percentage, :btrfs_increase_percentage)

      set_from_string_feature(:btrfs_default_subvolume, :btrfs_default_subvolume)
      read_subvolumes_section!
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
      "Storage ProposalSettings\n" \
        "  use_lvm: #{use_lvm}\n" \
        "  root_filesystem_type: #{root_filesystem_type}\n" \
        "  use_snapshots: #{use_snapshots}\n" \
        "  use_separate_home: #{use_separate_home}\n" \
        "  home_filesystem_type: #{home_filesystem_type}\n" \
        "  enlarge_swap_for_suspend: #{enlarge_swap_for_suspend}\n" \
        "  root_device: #{root_device}\n" \
        "  candidate_devices: #{candidate_devices}\n" \
        "  root_base_size: #{root_base_size}\n" \
        "  root_max_size: #{root_max_size}\n" \
        "  root_space_percent: #{root_space_percent}\n" \
        "  btrfs_increase_percentage: #{btrfs_increase_percentage}\n" \
        "  min_size_to_use_separate_home: #{min_size_to_use_separate_home}\n" \
        "  btrfs_default_subvolume: #{btrfs_default_subvolume}\n" \
        "  root_subvolume_read_only: #{root_subvolume_read_only}\n" \
        "  home_min_size: #{home_min_size}\n" \
        "  home_max_size: #{home_max_size}\n" \
        "  subvolumes: \n#{subvolumes}\n"
    end

    # List of Planned::BtrfsSubvolume objects based on the specifications stored
    # at #subvolumes (i.e. read from the product features).
    #
    # It includes only subvolumes that make sense for the current architecture
    # and avoids duplicated paths.
    #
    # @return [Array<Planned::BtrfsSubvolume>]
    def planned_subvolumes
      # Should not happen, #subvolumes is initialized in the constructor
      return [] if subvolumes.nil?

      subvolumes.each_with_object([]) do |subvol, result|
        new_planned = subvol.planned_subvolume
        next if new_planned.nil?

        # Overwrite previous definitions for the same path
        result.delete_if { |s| s.path == new_planned.path }

        result << new_planned
      end
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

    # Reads the "subvolumes" section of control.xml
    # @see SubvolSpecification.list_from_control_xml
    def read_subvolumes_section!
      xml = Yast::ProductFeatures.GetSection("partitioning")
      subvols = SubvolSpecification.list_from_control_xml(xml["subvolumes"])
      if subvols
        self.subvolumes = subvols
      else
        log.info "Unable to read subvolumes from the product features. Using fallback list."
      end
      subvolumes.each { |s| log.info("Initial #{s}") }
    end
  end
end
