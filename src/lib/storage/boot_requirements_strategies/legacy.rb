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

require "storage/boot_requirements_strategies/base"

module Yast
  module Storage
    module BootRequirementsStrategies
      # Strategy to calculate the boot requirements in a legacy system (x86
      # without EFI)
      class Legacy < Base

        using Refinements::Disk

        def needed_partitions
          volumes = super
          volumes << grub_volume if grub_partition_required? && grub_partition_missing?
          if mbr_gap_required?
            mbr_gap = disk_analyzer.mbr_gap[settings.root_device]
            # fail if gap is too small
            if mbr_gap < DiskSize.kiB(256)
              raise Proposal::Error
            end
          end
          volumes
        end

      protected

        def grub_partition_missing?
          partitions = disk_analyzer.grub_partitions[settings.root_device]
          partitions.nil? || partitions.empty?
        end

        # only needed on GPT partition table
        # FIXME: currently nobody creates a partition table on an empty disk...
        def grub_partition_required?
          if @root_disk &&
             @root_disk.partition_table? &&
             @root_disk.partition_table.type == ::Storage::PtType_GPT
            true
          else
            false
          end
        end

        # only relevant for DOS partition table
        def mbr_gap_required?
          if @root_disk &&
             @root_disk.partition_table? &&
             @root_disk.partition_table.type == ::Storage::PtType_MSDOS
            true
          else
            false
          end
        end

        def grub_volume
          vol = PlannedVolume.new(nil)
          # only required on GPT
          vol.partition_id = ::Storage::ID_GPT_BIOS
          vol.min_size = DiskSize.kiB(256)
          vol.max_size = DiskSize.MiB(8)
          vol.desired_size = DiskSize.MiB(1)
          vol.align = :keep_size
          vol.bootable = false
          vol.can_live_on_logical_volume = false
          vol
        end

      end
    end
  end
end
