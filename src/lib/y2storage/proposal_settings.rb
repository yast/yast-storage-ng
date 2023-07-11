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
require "y2storage/volume_specifications_set"
require "y2storage/encryption_method"
require "y2storage/equal_by_instance_variables"

module Y2Storage
  # Class to manage settings used by the proposal (typically read from control.xml)
  #
  # When a new object is created, all settings are nil or [] in case of a list is
  # expected. See {#for_current_product} to initialize settings with some values.
  class ProposalSettings
    include SecretAttributes
    include PartitioningFeatures
    include EqualByInstanceVariables

    # @return [Boolean] whether to use LVM
    attr_accessor :use_lvm

    # Whether the volumes specifying a separate_vg_name should
    # be indeed created as separate volume groups
    #
    # @return [Boolean] if false, all volumes will be treated equally (no
    #   special handling resulting in separate volume groups)
    attr_accessor :separate_vgs

    # Mode to use when allocating the volumes in the available devices
    #
    # @return [:auto, :device] :auto by default
    attr_accessor :allocate_volume_mode

    # Whether the initial proposal should use a multidisk approach
    #
    # @return [Boolean] if true, the initial proposal will be tried using all
    #   available candidate devices.
    attr_accessor :multidisk_first

    # Device name of the disk in which '/' must be placed.
    #
    # If it's set to nil and {#allocate_volume_mode} is :auto, the proposal will try
    # to find a good candidate
    #
    # @return [String, nil]
    def root_device
      if allocate_mode?(:device)
        root_volume ? root_volume.device : nil
      else
        @explicit_root_device
      end
    end

    # Sets {#root_device}
    #
    # If {#allocate_volume_mode} is :auto, this simply sets the value of the
    # attribute.
    #
    # If {#allocate_volume_mode} is :device this changes the value of
    # {VolumeSpecification#device} for the root volume and all its associated
    # volumes.
    def root_device=(name)
      @explicit_root_device = name

      return unless allocate_mode?(:device) && name

      root_set = volumes_sets.find(&:root?)
      root_set.device = name if root_set
    end

    # Most recent value of {#root_device} that was set via a call to the
    # {#root_device=} setter
    #
    # For settings with {#allocate_volume_mode} :auto, this is basically
    # equivalent to {#root_device}, but for settings with allocate mode :device,
    # the value of {#root_device} is usually a consequence of the status of the
    # {#volumes}. This method helps to identify the exception in which the root
    # device has been forced via the setter.
    #
    # @return [String, nil]
    attr_reader :explicit_root_device

    # Device names of the disks that can be used for the installation. If nil,
    # the proposal will try find suitable devices
    #
    # @return [Array<String>, nil]
    def candidate_devices
      if allocate_mode?(:device)
        # If any of the proposed volumes has no device assigned, the whole list
        # is invalid
        return nil if volumes.select(&:proposed).any? { |vol| vol.device.nil? }

        volumes.map(&:device).compact.uniq
      else
        @explicit_candidate_devices
      end
    end

    # Sets {#candidate_devices}
    #
    # If {#allocate_volume_mode} is :auto, this simply sets the value of the
    # attribute.
    #
    # If {#allocate_volume_mode} is :device this changes the value of
    # {VolumeSpecification#device} for all volumes using elements from the given
    # list.
    def candidate_devices=(devices)
      @explicit_candidate_devices = devices

      return unless allocate_mode?(:device)

      if devices.nil?
        volumes.each { |vol| vol.device = nil }
      else
        volumes_sets.select(&:proposed?).each_with_index do |set, idx|
          set.device = devices[idx] || devices.last
        end
      end
    end

    # Most recent value of {#candidate_devices} that was set via a call to the
    # {#candidate_devices=} setter
    #
    # For settings with {#allocate_volume_mode} :auto, this is basically
    # equivalent to {#candidate_devices}, but for settings with allocate mode
    # :device, the value of {#candidate_devices} is usually a consequence of the
    # status of the {#volumes}. This method helps to identify the exception in
    # which the list of devices has been forced via the setter.
    #
    # @return [Array<String>, nil]
    attr_reader :explicit_candidate_devices

    # TODO: it makes sense to encapsulate #encryption_password, #encryption_method and
    # #encryption_pbkdf in some new class (eg. EncryptionSettings), posponed for now

    # @!attribute encryption_password
    #   @return [String] password to use when creating new encryption devices
    secret_attr :encryption_password

    # Encryption method to use if {#encryption_password} is set
    #
    # @return [EncryptionMethod::Base]
    attr_accessor :encryption_method

    # PBKDF to use if {#encryption_password} is set and {#encryption_method} is LUKS2
    #
    # @return [PbkdFunction, nil] nil to use the default
    attr_accessor :encryption_pbkdf

    # @return [Boolean] whether to resize Windows systems if needed
    attr_accessor :resize_windows

    # What to do regarding removal of existing partitions hosting a Windows system.
    #
    # Options:
    #
    # * :none Never delete a Windows partition.
    # * :ondemand Delete Windows partitions as needed by the proposal.
    # * :all Delete all Windows partitions, even if not needed.
    #
    # @raise ArgumentError if any other value is assigned
    #
    # @return [Symbol]
    attr_reader :windows_delete_mode

    # @return [Symbol] what to do regarding removal of existing Linux
    #   partitions. See {DiskAnalyzer} for the definition of "Linux partitions".
    #   @see #windows_delete_mode for the possible values and exceptions
    attr_reader :linux_delete_mode

    # @return [Symbol] what to do regarding removal of existing partitions that
    #   don't fit in #windows_delete_mode or #linux_delete_mode.
    #   @see #windows_delete_mode for the possible values and exceptions
    attr_reader :other_delete_mode

    # Whether the delete mode of the partitions and the resize option for windows can be
    # configured. When this option is set to `false`, the {#windows_delete_mode}, {#linux_delete_mode},
    # {#other_delete_mode} and {#resize_windows} options cannot be modified by the user.
    #
    # @return [Boolean]
    attr_accessor :delete_resize_configurable

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
    # @return [Symbol] :use_available, :use_needed or :use_vg_size
    attr_reader :lvm_vg_strategy

    # @return [DiskSize] if :use_vg_size is specified in the previous option, this will
    #   specify the predefined size of the LVM volume group.
    attr_accessor :lvm_vg_size

    # @return [Boolean] whether a pre-existing LVM volume group should be reused if
    #   the conditions to do so are met. That is the historical YaST behavior, which
    #   can be inhibited by setting this to false.
    attr_accessor :lvm_vg_reuse

    # @return [Array<VolumeSpecification>] list of volumes specifications used during
    #   the proposal
    attr_accessor :volumes

    alias_method :lvm, :use_lvm
    alias_method :lvm=, :use_lvm=

    # Volumes grouped by their location in the disks.
    #
    # This method is only useful when #allocate_volume_mode is set to
    # :device. All the volumes that must be allocated in the same disk
    # are grouped in a single {VolumeSpecificationsSet} object.
    #
    # The sorting of {#volumes} is honored as long as possible
    #
    # @return [Array<VolumeSpecificationsSet>]
    def volumes_sets
      separate_vgs ? vol_sets_with_separate : vol_sets_plain
    end

    # New object initialized according to the YaST product features (i.e. /control.xml)
    # @return [ProposalSettings]
    def self.new_for_current_product
      settings = new
      settings.for_current_product
      settings
    end

    # Set settings according to the current product
    def for_current_product
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

    # List of all the supported settings
    SETTINGS = [
      :multidisk_first, :root_device, :explicit_root_device,
      :candidate_devices, :explicit_candidate_devices,
      :windows_delete_mode, :linux_delete_mode, :other_delete_mode, :resize_windows,
      :delete_resize_configurable,
      :lvm, :separate_vgs, :allocate_volume_mode, :lvm_vg_strategy, :lvm_vg_size
    ].freeze
    private_constant :SETTINGS

    def to_s
      "Storage ProposalSettings\n" \
      "  proposal:\n" +
        SETTINGS.map { |s| "    #{s}: #{send(s)}\n" }.join +
        "  volumes:\n" \
        "    #{volumes}"
    end

    # Check whether using btrfs filesystem with snapshots for root
    #
    # @return [Boolean]
    def snapshots_active?
      root_volume.nil? ? false : root_volume.snapshots?
    end

    # Forces to enable snapshots for the root subvolume
    #
    # After calling this method, snapshots will not be configurable.
    def force_enable_snapshots
      return unless root_volume

      root_volume.snapshots = true
      root_volume.snapshots_configurable = false
    end

    # Forces to disable snapshots for the root subvolume
    #
    # After calling this method, snapshots will not be configurable.
    def force_disable_snapshots
      return unless root_volume

      root_volume.snapshots = false
      root_volume.snapshots_configurable = false
    end

    # Checks the value of {#allocate_volume_mode}
    #
    # @return [Boolean]
    def allocate_mode?(mode)
      allocate_volume_mode == mode
    end

    # Whether the value of {#separate_vgs} is relevant
    #
    # The mentioned setting only makes sense when there is at least one volume
    # specification at {#volumes} which contains a separate VG name.
    #
    # @return [Boolean]
    def separate_vgs_relevant?
      volumes.any?(&:separate_vg_name)
    end

    private

    # Volume specification for the root filesystem
    #
    # @return [VolumeSpecification]
    def root_volume
      volumes.find(&:root?)
    end

    # List of possible delete strategies.
    # TODO: enum?
    DELETE_MODES = [:none, :all, :ondemand]
    private_constant :DELETE_MODES

    # List of possible VG strategies.
    # TODO: enum?
    LVM_VG_STRATEGIES = [:use_available, :use_needed, :use_vg_size]
    private_constant :LVM_VG_STRATEGIES

    # Defaults when a setting is not specified
    DEFAULTS = {
      allocate_volume_mode:       :auto,
      delete_resize_configurable: true,
      linux_delete_mode:          :ondemand,
      lvm:                        false,
      lvm_vg_strategy:            :use_available,
      lvm_vg_reuse:               true,
      encryption_method:          EncryptionMethod::LUKS1,
      multidisk_first:            false,
      other_delete_mode:          :ondemand,
      resize_windows:             true,
      separate_vgs:               false,
      volumes:                    [],
      windows_delete_mode:        :ondemand
    }
    private_constant :DEFAULTS

    # Sets default values for the settings.
    # These will be the final values when the setting is not specified in the control file
    def apply_defaults
      DEFAULTS.each do |key, value|
        send(:"#{key}=", value) if send(key).nil?
      end
    end

    # Overrides the settings with values read from the YaST product features
    # (i.e. values in /control.xml).
    #
    # Settings omitted in the product features are not modified.
    def load_features
      load_feature(:proposal, :lvm)
      load_feature(:proposal, :separate_vgs)
      load_feature(:proposal, :resize_windows)
      load_feature(:proposal, :windows_delete_mode)
      load_feature(:proposal, :linux_delete_mode)
      load_feature(:proposal, :other_delete_mode)
      load_feature(:proposal, :delete_resize_configurable)
      load_feature(:proposal, :lvm_vg_strategy)
      load_feature(:proposal, :allocate_volume_mode)
      load_feature(:proposal, :multidisk_first)
      load_size_feature(:proposal, :lvm_vg_size)
      load_volumes_feature(:volumes)
      load_encryption
    end

    # Loads the default encryption settings
    #
    # The encryption settings are not part of control.xml, but can be injected by a previous step of
    # the installation, eg. the dialog of the Common Criteria system role
    def load_encryption
      enc = feature(:proposal, :encryption)

      return unless enc
      return unless enc.respond_to?(:password)

      passwd = enc.password.to_s
      return if passwd.nil? || passwd.empty?

      self.encryption_password = passwd
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
      raise ArgumentError, "Invalid feature value: #{value}" if !valid_values.include?(result)

      result
    end

    # Implementation for {#volumes_sets} when {#separate_vgs} is set to false
    #
    # @see #volumes_sets
    #
    # @return [Array<VolumeSpecificationsSet]
    def vol_sets_plain
      if lvm
        [VolumeSpecificationsSet.new(volumes.dup, :lvm)]
      else
        volumes.map { |vol| VolumeSpecificationsSet.new([vol], :partition) }
      end
    end

    # Implementation for {#volumes_sets} when {#separate_vgs} is set to true
    #
    # @see #volumes_sets
    #
    # @return [Array<VolumeSpecificationsSet]
    def vol_sets_with_separate
      sets = []

      volumes.each do |vol|
        if vol.separate_vg_name
          # There should not be two volumes with the same separate_vg_name. But
          # just in case, let's group them if that happens.
          group = sets.find { |s| s.vg_name == vol.separate_vg_name }
          type = :separate_lvm
        elsif lvm
          group = sets.find { |s| s.type == :lvm }
          type = :lvm
        else
          group = nil
          type = :partition
        end

        if group
          group.push(vol)
        else
          sets << VolumeSpecificationsSet.new([vol], type)
        end
      end

      sets
    end
  end
end
