#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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

require "fileutils"
require "y2storage/planned"
require "y2storage/disk_size"
require "y2storage/boot_requirements_checker"
require "y2storage/snapper_config.rb"
require "y2storage/exceptions"

module Y2Storage
  module Proposal
    #
    # Class to generate the list of planned devices of a proposal
    #
    class DevicesPlanner
      include Yast::Logger

      attr_accessor :settings

      MIN_SWAP_SIZE = DiskSize.MiB(512)
      MAX_SWAP_SIZE = DiskSize.GiB(2) # This is also DEFAULT_SWAP_SIZE
      SWAP_WEIGHT = 100 # Importance of swap if low free disk space

      def initialize(settings, devicegraph)
        @settings = settings
        @devicegraph = devicegraph
        SnapperConfig.reset
      end

      # Devices that needs to be created to satisfy the settings
      #
      # @param target [Symbol] :desired means the sizes of the planned devices
      #   should be the ideal ones, :min for generating the smallest functional
      #   devices
      # @return [Array<Planned::Device>]
      def planned_devices(target)
        @target = target
        devices = base_devices + additional_devices
        remove_shadowed_subvols(devices)
        devices
      end

    protected

      attr_reader :devicegraph

      # Minimal set of devices that is needed to decide if a bootable
      # system can be installed
      #
      # This includes "/" and the devices needed for booting
      #
      # @return [Array<Planned::Device>]
      def base_devices
        root = root_device
        boot_devices(root) + [root]
      end

      # Planned devices needed by the bootloader
      #
      # @return [Array<Planned::Device>]
      def boot_devices(root_dev)
        checker = BootRequirementsChecker.new(
          devicegraph, planned_devices: [root_dev], boot_disk_name: settings.root_device
        )
        checker.needed_partitions(@target)
      rescue BootRequirementsChecker::Error => error
        # As documented, {BootRequirementsChecker#needed_partition} raises this
        # exception if it's impossible to get a bootable system, even adding
        # more partitions.
        raise NotBootableError, error.message
      end

      # Additional devices not needed for booting, like swap and /home
      #
      # @return [Array<Planned::Device>]
      def additional_devices
        devices = [swap_device]
        devices << home_device if @settings.use_separate_home
        devices
      end

      # Device to host the swap space according to the settings.
      def swap_device
        min_size = max_size = MAX_SWAP_SIZE
        if settings.enlarge_swap_for_suspend
          min_size = max_size = [ram_size, max_size].max
        elsif @target == :min
          min_size = MIN_SWAP_SIZE
          # leave max_size alone so any leftover free space can be distributed
          # to swap, too according to SWAP_WEIGHT
        end
        if settings.use_lvm
          swap_lv(min_size, max_size)
        else
          swap_partition(min_size, max_size)
        end
      end

      def swap_lv(min_size, max_size)
        lv = Planned::LvmLv.new("swap", Filesystems::Type::SWAP)
        lv.logical_volume_name = "swap"
        lv.min_size = min_size
        lv.max_size = max_size
        lv.weight = SWAP_WEIGHT
        lv
      end

      def swap_partition(min_size, max_size)
        part = Planned::Partition.new("swap", Filesystems::Type::SWAP)
        part.encryption_password = settings.encryption_password
        # NOTE: Enforcing the re-use of an existing partition limits the options
        # to propose a valid distribution of the planned partitions. For swap we
        # already have mechanisms to reuse UUIDs and labels, so maybe is smarter
        # to never reuse partitions as-is.
        reuse = reusable_swap(max_size)
        if reuse
          part.reuse = reuse.name
        else
          part.min_size = min_size
          part.max_size = max_size
          part.weight = SWAP_WEIGHT
        end
        part
      end

      # Swap partition that can be reused.
      #
      # It returns the smaller partition that is big enough for our purposes.
      #
      # @return [Partition]
      def reusable_swap(required_size)
        return nil if settings.use_lvm || settings.use_encryption

        partitions = devicegraph.disk_devices.map(&:swap_partitions).flatten
        partitions.select! { |part| part.size >= required_size }
        # Use #name in case of #size tie to provide stable sorting
        partitions.sort_by { |part| [part.size, part.name] }.first
      end

      # Planned device to hold "/" according to the settings.
      def root_device
        if settings.use_lvm
          root_vol = Planned::LvmLv.new("/", @settings.root_filesystem_type)
        else
          root_vol = Planned::Partition.new("/", @settings.root_filesystem_type)
          root_vol.disk = @settings.root_device
          root_vol.encryption_password = @settings.encryption_password
        end
        root_vol.weight   = @settings.root_space_percent
        root_vol.max_size = @settings.root_max_size
        root_vol.min_size =
          if @target == :min || root_vol.max_size.unlimited?
            @settings.root_base_size
          else
            root_vol.max_size
          end
        adjust_btrfs_sizes!(root_vol)
        init_btrfs_subvolumes!(root_vol)
        root_vol.use_snapshots
        enable_root_snapshots(root) if @settings.use_snapshots
        root_vol
      end

      # Enable snapshots on a Btrfs root volume.
      # @param root_vol [PlannedDevice]
      def enable_root_snapshots(root_vol)
        return unless root_vol.btrfs?
        root_vol.use_snapshots = true
        SnapperConfig.configure_snapper = true
      end

      # Sizes have to be adjusted only when using snapshots
      def adjust_btrfs_sizes!(planned_device)
        return if !planned_device.btrfs? || !settings.use_snapshots

        log.info "Increasing root filesystem size for snapshots"
        multiplicator = 1.0 + settings.btrfs_increase_percentage / 100.0
        planned_device.min_size *= multiplicator
        planned_device.max_size *= multiplicator
      end

      def init_btrfs_subvolumes!(planned_device)
        return unless planned_device.btrfs? && settings.subvolumes

        planned_device.default_subvolume = settings.btrfs_default_subvolume || ""
        planned_device.subvolumes = settings.subvolumes
        log.info "Adding Btrfs subvolumes: \n#{planned_device.subvolumes}"
      end

      # Planned device to hold "/home" according to the settings.
      def home_device
        if settings.use_lvm
          home_vol = Planned::LvmLv.new("/home", settings.home_filesystem_type)
        else
          home_vol = Planned::Partition.new("/home", settings.home_filesystem_type)
          home_vol.encryption_password = settings.encryption_password
        end
        home_vol.max_size = settings.home_max_size
        home_vol.min_size =
          if @target == :min
            settings.root_base_size
          else
            settings.home_min_size
          end
        home_vol.weight = 100.0 - settings.root_space_percent
        home_vol
      end

      def remove_shadowed_subvols(planned_devices)
        planned_devices.each do |device|
          next unless device.respond_to?(:subvolumes)

          device.shadowed_subvolumes(planned_devices).each do |subvol|
            log.info "Subvolume #{subvol} would be shadowed. Removing it."
            device.subvolumes.delete(subvol)
          end
        end
      end

      # Return the total amount of RAM as DiskSize
      #
      # @return [DiskSize] current RAM size
      #
      def ram_size
        # FIXME: use the .proc.meminfo agent and its MemTotal field
        #   mem_info_map = Convert.to_map(SCR.Read(path(".proc.meminfo")))
        # See old Partitions.rb: SwapSizeMb()
        DiskSize.GiB(8)
      end
    end
  end
end
