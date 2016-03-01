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
require "storage/planned_volume"
require "storage/planned_volumes_collection"
require "storage/disk_size"
require "storage/boot_requirements_checker"

module Yast
  module Storage
    class Proposal
      #
      # Class to generate the list of planned volumes of a proposal
      #
      class VolumesGenerator
        attr_accessor :settings

        DEFAULT_SWAP_SIZE = DiskSize.GiB(2)

        def initialize(settings)
          @settings = settings
        end

        # Volumes that needs to be created to satisfy the settings
        #
        # @return [PlannedVolumnesCollection]
        def volumes
          PlannedVolumesCollection.new(boot_volumes.to_a + standard_volumes)
        end

        protected

        # Volumes needed by the bootloader
        #
        # @return [Array<PlannedVolumes>]
        def boot_volumes
          checker = BootRequirementsChecker.new(settings)
          checker.needed_partitions
        end

        # Standard volumes for the root, swap and /home
        #
        # @return [Array<PlannedVolumes>]
        def standard_volumes
          volumes = [swap_volume, root_volume]
          volumes << home_volume if @settings.use_separate_home
          volumes
        end

        # Volume data structure for the swap volume according
        # to the settings.
        def swap_volume
          vol = PlannedVolume.new("swap", ::Storage::FsType_SWAP)
          swap_size = DEFAULT_SWAP_SIZE
          if @settings.enlarge_swap_for_suspend
            swap_size = [ram_size, swap_size].max
          end
          vol.min_size     = swap_size
          vol.max_size     = swap_size
          vol.desired_size = swap_size
          vol
        end

        # Volume data structure for the root volume according
        # to the settings.
        #
        # This does NOT create the partition yet, only the data structure.
        #
        def root_volume
          root_vol = PlannedVolume.new("/", @settings.root_filesystem_type)
          root_vol.min_size = @settings.root_base_size
          root_vol.max_size = @settings.root_max_size
          root_vol.weight   = @settings.root_space_percent
          if root_vol.filesystem_type == ::Storage::FsType_BTRFS
            puts("Increasing root filesystem size for Btrfs")
            multiplicator = 1.0 + @settings.btrfs_increase_percentage / 100.0
            root_vol.min_size *= multiplicator
            root_vol.max_size *= multiplicator
          end
          root_vol.desired_size = root_vol.max_size
          root_vol
        end

        # Volume data structure for the /home volume according
        # to the settings.
        #
        # This does NOT create the partition yet, only the data structure.
        #
        def home_volume
          home_vol = PlannedVolume.new("/home", settings.home_filesystem_type)
          home_vol.min_size = settings.home_min_size
          home_vol.max_size = settings.home_max_size
          home_vol.weight   = 100.0 - settings.root_space_percent
          home_vol
        end

        # Return the total amount of RAM as DiskSize
        #
        # @return [DiskSize] current RAM size
        #
        def ram_size
          # FIXME use the .proc.meminfo agent and its MemTotal field
          #   mem_info_map = Convert.to_map(SCR.Read(path(".proc.meminfo")))
          # See old Partitions.rb: SwapSizeMb()
          DiskSize.GiB(8)
        end
      end
    end
  end
end
