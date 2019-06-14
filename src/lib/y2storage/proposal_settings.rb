# encoding: utf-8

# Copyright (c) [2015-2019] SUSE LLC
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
require "y2storage/volume_specification"
require "y2storage/subvol_specification"
require "y2storage/filesystems/type"
require "y2storage/partitioning_features"

module Y2Storage
  # Class to manage settings used by the proposal (typically read from control.xml)
  #
  # When a new object is created, all settings are nil or [] in case of a list is
  # expected. See {#for_current_product} to initialize settings with some values.
  class ProposalSettings
    include SecretAttributes
    include PartitioningFeatures

    # @note :legacy format
    # @return [Boolean] whether to use LVM
    attr_accessor :use_lvm

    # Whether the volumes specifying a separate_vg_name should
    # be indeed created as separate volume groups
    #
    # @note :ng format
    #
    # @return [Boolean] if false, all volumes will be treated equally (no
    #   special handling resulting in separate volume groups)
    attr_accessor :separate_vgs

    # @note :legacy format
    # @return [Filesystems::Type] type to use for the root filesystem
    attr_accessor :root_filesystem_type

    # @note :legacy format
    # @return [Boolean] whether to enable snapshots (only if Btrfs is used)
    attr_accessor :use_snapshots

    # @note :legacy format
    # @return [Boolean] whether to propose separate partition/volume for /home
    attr_accessor :use_separate_home

    # @note :legacy format
    # @return [Filesystems::Type] type to use for the home filesystem, if a
    #   separate one is proposed
    attr_accessor :home_filesystem_type

    # @note :legacy format
    # @return [Boolean] whether to enlarge swap based on the RAM size, to ensure
    #   the classic suspend-to-ram works
    attr_accessor :enlarge_swap_for_suspend

    # @note :legacy format
    # @return [DiskSize] root size used when calculating the :min size for
    #   the proposal.
    attr_accessor :root_base_size

    # @note :legacy format
    # @return [DiskSize] maximum allowed size for root. This size is also used as
    #   base size when calculating the :desired size for the proposal.
    attr_accessor :root_max_size

    # @note :legacy format
    # @return [Numeric] used to adjust size when distributing extra space
    attr_accessor :root_space_percent

    # @note :legacy format
    # @return [Numeric] used to adjust size when using snapshots
    attr_accessor :btrfs_increase_percentage

    # @note :legacy format
    # @return [DiskSize] min disk size to allow a separate home
    attr_accessor :min_size_to_use_separate_home

    # @note :legacy format
    # @return [String] default btrfs subvolume path
    attr_accessor :btrfs_default_subvolume

    # @note :legacy format
    # @return [DiskSize] home size used when calculating the :min size for
    #   the proposal. If space is tight, {root_base_size} is used instead.
    #   See also {Y2Storage::DevicesPlannerStrategies::Legacy#home_device}.
    attr_accessor :home_min_size

    # @note :legacy format
    # @return [DiskSize] maximum allowed size for home. This size is also used as
    #   base size when calculating the :desired size for the proposal.
    attr_accessor :home_max_size

    # @note :legacy format
    # @return [Array<SubvolSpecification>] list of specifications (usually read
    #   from the control file) that will be used to plan the Btrfs subvolumes of
    #   the root filesystem
    attr_accessor :subvolumes

    # @note :legacy and :ng formats
    # @return [String] device name of the disk in which / must be placed. If set
    #   to nil, the proposal will try to find a good candidate
    attr_accessor :root_device

    # @note :legacy and :ng formats
    # @return [Boolean] whether to resize Windows systems if needed
    attr_accessor :resize_windows

    # @note :legacy and :ng formats
    # @return [Array<String>] device names of the disks that can be used for the
    #   installation. If nil, the proposal will try find suitable devices
    attr_accessor :candidate_devices

    # @!attribute encryption_password
    #   @note :legacy and :ng formats
    #   @return [String] password to use when creating new encryption devices
    secret_attr :encryption_password

    # What to do regarding removal of existing partitions hosting a Windows system.
    #
    # Options:
    #
    # * :none Never delete a Windows partition.
    # * :ondemand Delete Windows partitions as needed by the proposal.
    # * :all Delete all Windows partitions, even if not needed.
    #
    # @note :legacy and :ng formats
    #
    # @raise ArgumentError if any other value is assigned
    #
    # @return [Symbol]
    attr_reader :windows_delete_mode

    # @note :legacy and :ng formats
    # @return [Symbol] what to do regarding removal of existing Linux
    #   partitions. See {DiskAnalyzer} for the definition of "Linux partitions".
    #   @see #windows_delete_mode for the possible values and exceptions
    attr_reader :linux_delete_mode

    # @note :legacy and :ng formats
    # @return [Symbol] what to do regarding removal of existing partitions that
    #   don't fit in #windows_delete_mode or #linux_delete_mode.
    #   @see #windows_delete_mode for the possible values and exceptions
    attr_reader :other_delete_mode

    # When the user decides to use LVM, strategy to decide the size of the volume
    # group (and, thus, the number and size of created physical volumes).
    #
    # Options:
    #
    # * :use_available The VG will be created to use all the available space, thus the
    #   VG size could be greater than the sum of LVs sizes.
    # * :use_needed The created VG will match the requirements 1:1, so its size will be
    #   exactly the sum of all the LVs sizes.
    # * :use_vg_size The VG will have a predefined size, that could be greater than the
    #   LVs sizes.
    #
    # @note :ng format
    #
    # @return [Symbol] :use_available, :use_needed or :use_vg_size
    attr_reader :lvm_vg_strategy

    # @note :ng format
    # @return [DiskSize] if :use_vg_size is specified in the previous option, this will
    #   specify the predefined size of the LVM volume group.
    attr_accessor :lvm_vg_size

    # @note :ng format
    # @return [Array<VolumeSpecification>] list of volumes specifications used during
    #   the proposal
    attr_accessor :volumes

    # Format of <partitioning> section
    # @return [Symbol] :legacy, :ng
    attr_reader :format

    alias_method :lvm, :use_lvm
    alias_method :lvm=, :use_lvm=

    LEGACY_FORMAT = :legacy
    NG_FORMAT = :ng

    # New object initialized according to the YaST product features (i.e. /control.xml)
    # @return [ProposalSettings]
    def self.new_for_current_product
      settings = new
      settings.for_current_product
      settings
    end

    # Set settings according to the current product
    def for_current_product
      @format = features_format
      apply_defaults
      load_features
    end

    # Produces a deep copy of settings
    #
    # @return [ProposalSettings]
    def deep_copy
      Marshal.load(Marshal.dump(self))
    end

    # Whether encryption must be used
    # @return [Boolean]
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

    def windows_delete_mode=(mode)
      @windows_delete_mode = validated_delete_mode(mode)
    end

    def linux_delete_mode=(mode)
      @linux_delete_mode = validated_delete_mode(mode)
    end

    def other_delete_mode=(mode)
      @other_delete_mode = validated_delete_mode(mode)
    end

    def lvm_vg_strategy=(strategy)
      @lvm_vg_strategy = validated_lvm_vg_strategy(strategy)
    end

    def to_s
      ng_format? ? ng_string_representation : legacy_string_representation
    end

    # Check whether using btrfs filesystem with snapshots for root
    #
    # @return [Boolean]
    def snapshots_active?
      ng_format? ? ng_check_root_snapshots : legacy_check_root_snapshots
    end

    def ng_format?
      format == NG_FORMAT
    end

    # FIXME: Improve implementation. Use composition to encapsulate logic for
    # ng and legacy format
    def legacy_btrfs_default_subvolume
      return btrfs_default_subvolume unless ng_format?
      return nil if volumes.empty?
      root_volume = volumes.find { |v| v.mount_point == "/" }
      return root_volume.btrfs_default_subvolume if root_volume
      volumes.first.btrfs_default_subvolume
    end

  private

    DELETE_MODES = [:none, :all, :ondemand]
    private_constant :DELETE_MODES

    LVM_VG_STRATEGIES = [:use_available, :use_needed, :use_vg_size]
    private_constant :LVM_VG_STRATEGIES

    # Format used in control file
    #
    # Format is considered :ng only if subsections <proposal> and <volumes> are
    # present in the 'partitioning' section.
    #
    # @note When there is no <partitioning> section, legacy format is considered.
    #
    # @return [Symbol, nil] :ng or :legacy
    def features_format
      return LEGACY_FORMAT if partitioning_section.nil?

      has_ng_subsections = partitioning_section.key?("proposal") && partitioning_section.key?("volumes")
      has_ng_subsections ? NG_FORMAT : LEGACY_FORMAT
    end

    # Sets default values for the settings.
    # These will be the final values when the setting is not specified in the control file
    def apply_defaults
      ng_format? ? apply_ng_defaults : apply_legacy_defaults
    end

    # Overrides the settings with values read from the YaST product features
    # (i.e. values in /control.xml).
    #
    # Settings omitted in the product features are not modified.
    def load_features
      ng_format? ? load_ng_features : load_legacy_features
    end

    # FIXME: Improve implementation. Use composition to encapsulate logic for
    # ng and legacy formats
    def apply_ng_defaults
      self.lvm                 ||= false
      self.separate_vgs        ||= false
      self.resize_windows      ||= true
      self.windows_delete_mode ||= :ondemand
      self.linux_delete_mode   ||= :ondemand
      self.other_delete_mode   ||= :ondemand
      self.lvm_vg_strategy     ||= :use_available
      self.volumes             ||= []
    end

    # FIXME: Improve implementation. Use composition to encapsulate logic for
    # ng and legacy formats
    def load_ng_features
      load_feature(:proposal, :lvm)
      load_feature(:proposal, :separate_vgs)
      load_feature(:proposal, :resize_windows)
      load_feature(:proposal, :windows_delete_mode)
      load_feature(:proposal, :linux_delete_mode)
      load_feature(:proposal, :other_delete_mode)
      load_feature(:proposal, :lvm_vg_strategy)
      load_size_feature(:proposal, :lvm_vg_size)
      load_volumes_feature(:volumes)
    end

    # FIXME: Improve implementation. Use composition to encapsulate logic for
    # ng and legacy formats
    def apply_legacy_defaults
      apply_default_legacy_sizes
      self.use_lvm                   ||= false
      self.lvm_vg_strategy           ||= :use_available
      self.encryption_password       ||= nil
      self.root_filesystem_type      ||= Y2Storage::Filesystems::Type::BTRFS
      self.use_snapshots             ||= true
      self.use_separate_home         ||= true
      self.home_filesystem_type      ||= Y2Storage::Filesystems::Type::XFS
      self.enlarge_swap_for_suspend  ||= false
      self.resize_windows            ||= true
      self.windows_delete_mode       ||= :ondemand
      self.linux_delete_mode         ||= :ondemand
      self.other_delete_mode         ||= :ondemand
      self.root_space_percent        ||= 40
      self.btrfs_increase_percentage ||= 300.0
      self.btrfs_default_subvolume   ||= "@"
      self.subvolumes                ||= SubvolSpecification.fallback_list
    end

    # FIXME: Improve implementation. Use composition to encapsulate logic for
    # ng and legacy formats
    def apply_default_legacy_sizes
      self.root_base_size                ||= Y2Storage::DiskSize.GiB(3)
      self.root_max_size                 ||= Y2Storage::DiskSize.GiB(10)
      self.min_size_to_use_separate_home ||= Y2Storage::DiskSize.GiB(5)
      self.home_min_size                 ||= Y2Storage::DiskSize.GiB(10)
      self.home_max_size                 ||= Y2Storage::DiskSize.unlimited
    end

    # FIXME: Improve implementation. Use composition to encapsulate logic for
    # ng and legacy formats
    def load_legacy_features
      load_feature(:proposal_lvm, to: :use_lvm)
      load_feature(:try_separate_home, to: :use_separate_home)
      load_feature(:proposal_snapshots, to: :use_snapshots)
      load_feature(:swap_for_suspend, to: :enlarge_swap_for_suspend)
      load_size_feature(:root_base_size)
      load_size_feature(:root_max_size)
      load_size_feature(:vm_home_max_size, to: :home_max_size)
      load_size_feature(:limit_try_home, to: :min_size_to_use_separate_home)
      load_integer_feature(:root_space_percent)
      load_integer_feature(:btrfs_increase_percentage)
      load_feature(:btrfs_default_subvolume)
      load_subvolumes_feature(:subvolumes)
    end

    def validated_delete_mode(mode)
      validated_feature_value(mode, DELETE_MODES)
    end

    def validated_lvm_vg_strategy(strategy)
      validated_feature_value(strategy, LVM_VG_STRATEGIES)
    end

    def validated_feature_value(value, valid_values)
      raise ArgumentError, "Invalid feature value: #{value}" unless value
      result = value.to_sym
      if !valid_values.include?(result)
        raise ArgumentError, "Invalid feature value: #{value}"
      end
      result
    end

    # FIXME: Improve implementation. Use composition to encapsulate logic for
    # ng and legacy format
    def ng_check_root_snapshots
      root_volume = volumes.detect { |v| v.mount_point == "/" }
      root_volume.nil? ? false : root_volume.snapshots?
    end

    # FIXME: Improve implementation. Use composition to encapsulate logic for
    # ng and legacy format
    def legacy_check_root_snapshots
      root_filesystem_type.is?(:btrfs) && use_snapshots
    end

    # FIXME: Improve implementation. Use composition to encapsulate logic for
    # ng and legacy formats
    def ng_string_representation
      "Storage ProposalSettings (#{format})\n" \
      "  proposal:\n" \
      "    lvm: #{lvm}\n" \
      "    windows_delete_mode: #{windows_delete_mode}\n" \
      "    linux_delete_mode: #{linux_delete_mode}\n" \
      "    other_delete_mode: #{other_delete_mode}\n" \
      "    resize_windows: #{resize_windows}\n" \
      "    lvm_vg_strategy: #{lvm_vg_strategy}\n" \
      "    lvm_vg_size: #{lvm_vg_size}\n" \
      "  volumes:\n" \
      "    #{volumes}"
    end

    # FIXME: Improve implementation. Use composition to encapsulate logic for
    # ng and legacy formats
    def legacy_string_representation
      "Storage ProposalSettings (#{format})\n" \
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
      "  home_min_size: #{home_min_size}\n" \
      "  home_max_size: #{home_max_size}\n" \
      "  subvolumes: \n#{subvolumes}\n"
    end
  end
end
