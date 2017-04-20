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
require "y2storage/planned_volume"
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
      def volumes
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
      # @return [Array<PlannedVolumes>]
      def boot_volumes
        checker = BootRequirementsChecker.new(settings, devicegraph)
        checker.needed_partitions
      rescue BootRequirementsChecker::Error => error
        raise NotBootableError, error.message
      end

      # Additional volumes not needed for booting, like swap and /home
      #
      # @return [Array<PlannedVolumes>]
      def additional_volumes
        volumes = [swap_volume]
        volumes << home_volume if @settings.use_separate_home
        volumes
      end

      # Volume data structure for the swap volume according
      # to the settings.
      def swap_volume
        swap_size = DEFAULT_SWAP_SIZE
        if @settings.enlarge_swap_for_suspend
          swap_size = [ram_size, swap_size].max
        end
        vol = PlannedVolume.new("swap", Filesystems::Type::SWAP)
        vol.plain_partition = false
        vol.logical_volume_name = "swap"
        # NOTE: Enforcing the re-use of an existing partition limits the options
        # to propose a valid distribution of the volumes. For swap we already
        # have mechanisms to reuse UUIDs and labels, so maybe is smarter to
        # never reuse partitions as-is.
        reuse = reusable_swap(swap_size)
        if reuse
          vol.reuse = reuse.name
        else
          vol.min_disk_size     = swap_size
          vol.max_disk_size     = swap_size
          vol.desired_disk_size = swap_size
        end
        vol
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
        root_vol = PlannedVolume.new("/", @settings.root_filesystem_type)
        root_vol.min_disk_size = @settings.root_base_disk_size
        root_vol.max_disk_size = @settings.root_max_disk_size
        root_vol.weight   = @settings.root_space_percent
        root_vol.disk     = @settings.root_device
        if root_vol.btrfs?
          log.info "Increasing root filesystem size for Btrfs"
          multiplicator = 1.0 + @settings.btrfs_increase_percentage / 100.0
          root_vol.min_disk_size *= multiplicator
          root_vol.max_disk_size *= multiplicator
          root_vol.default_subvolume = @settings.btrfs_default_subvolume
          root_vol.subvolumes = @settings.subvolumes
          log.info "Adding Btrfs subvolumes: \n#{root_vol.subvolumes}"
        end
        root_vol.desired_disk_size = root_vol.max_disk_size
        root_vol
      end

      # Volume data structure for the /home volume according
      # to the settings.
      #
      # This does NOT create the partition yet, only the data structure.
      #
      def home_volume
        home_vol = PlannedVolume.new("/home", settings.home_filesystem_type)
        home_vol.min_disk_size = settings.home_min_disk_size
        home_vol.max_disk_size = settings.home_max_disk_size
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
