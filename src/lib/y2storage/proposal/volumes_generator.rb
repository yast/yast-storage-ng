#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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
require "y2storage/planned_volumes_list"
require "y2storage/disk_size"
require "y2storage/boot_requirements_checker"
require "y2storage/proposal/exceptions"

module Y2Storage
  class Proposal
    #
    # Class to generate the list of planned volumes of a proposal
    #
    class VolumesGenerator
      include Yast::Logger

      attr_accessor :settings

      DEFAULT_SWAP_SIZE = DiskSize.GiB(2)

      def initialize(settings, devicegraph)
        @settings = settings
        @devicegraph = devicegraph
      end

      # Volumes that needs to be created to satisfy the settings
      #
      # @return [PlannedVolumesList]
      def volumes(target)
        @target = target
        PlannedVolumesList.new(base_volumes.to_a + additional_volumes)
      end

    protected

      attr_reader :devicegraph

      # Minimal set of volumes that is needed to decide if a bootable
      # system can be installed
      #
      # This includes "/" and the volumes needed for booting
      #
      # @return [PlannedVolumesList]
      def base_volumes
        PlannedVolumesList.new(boot_volumes.to_a + [root_volume])
      end

      # Volumes needed by the bootloader
      #
      # @return [Array<Planned::Partition>]
      def boot_volumes
        checker = BootRequirementsChecker.new(settings, devicegraph)
        checker.needed_partitions(@target)
      rescue BootRequirementsChecker::Error => error
        raise NotBootableError, error.message
      end

      # Additional volumes not needed for booting, like swap and /home
      #
      # @return [Array<Planned::Base>]
      def additional_volumes
        volumes = [swap_volume]
        volumes << home_volume if @settings.use_separate_home
        volumes
      end

      # Volume data structure for the swap volume according
      # to the settings.
      def swap_volume
        swap_size = DEFAULT_SWAP_SIZE
        if settings.enlarge_swap_for_suspend
          swap_size = [ram_size, swap_size].max
        end
        if settings.use_lvm
          swap_lv(swap_size)
        else
          swap_partition(swap_size)
        end
      end

      def swap_lv(size)
        lv = Planned::LvmLv.new("swap", Filesystems::Type::SWAP)
        lv.logical_volume_name = "swap"
        lv.min_size = size
        lv.max_size = size
        lv
      end

      def swap_partition(size)
        part = Planned::Partition.new("swap", Filesystems::Type::SWAP)
        part.encryption_password = settings.encryption_password
        # NOTE: Enforcing the re-use of an existing partition limits the options
        # to propose a valid distribution of the volumes. For swap we already
        # have mechanisms to reuse UUIDs and labels, so maybe is smarter to
        # never reuse partitions as-is.
        reuse = reusable_swap(size)
        if reuse
          part.reuse = reuse.name
        else
          part.min_size  = size
          part.max_size  = size
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

        partitions = devicegraph.disks.map(&:swap_partitions).flatten
        partitions.select! { |part| part.size >= required_size }
        # Use #name in case of #size tie to provide stable sorting
        partitions.sort_by { |part| [part.size, part.name] }.first
      end

      # Volume data structure for the root volume according
      # to the settings.
      #
      # This does NOT create the partition yet, only the data structure.
      #
      def root_volume
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
        root_vol
      end

      def adjust_btrfs_sizes!(planned_device)
        return unless planned_device.btrfs?

        log.info "Increasing root filesystem size for Btrfs"
        multiplicator = 1.0 + settings.btrfs_increase_percentage / 100.0
        planned_device.min_size *= multiplicator
        planned_device.max_size *= multiplicator

        planned_device.default_subvolume = settings.btrfs_default_subvolume || ""
        planned_device.subvolumes = settings.subvolumes
        log.info "Adding Btrfs subvolumes: \n#{planned_device.subvolumes}"
      end

      # Volume data structure for the /home volume according
      # to the settings.
      #
      # This does NOT create the partition yet, only the data structure.
      #
      def home_volume
        if settings.use_lvm
          home_vol = Planned::LvmLv.new("/home", settings.home_filesystem_type)
        else
          home_vol = Planned::Partition.new("/home", settings.home_filesystem_type)
          home_vol.encryption_password = settings.encryption_password
        end
        home_vol.max_size = settings.home_max_size
        home_vol.min_size = settings.home_min_size
        home_vol.weight = 100.0 - settings.root_space_percent
        home_vol
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
