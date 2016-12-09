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

require "y2storage/boot_requirements_strategies/base"

module Y2Storage
  module BootRequirementsStrategies
    # Strategy to calculate boot requirements in UEFI systems
    class UEFI < Base
      def needed_partitions
        volumes = super
        volumes << efi_volume
        volumes
      end

    protected

      def efi_volume
        vol = PlannedVolume.new("/boot/efi", ::Storage::FsType_VFAT)
        if reusable_efi
          vol.reuse = reusable_efi.name
        else
          # So far we are always using msdos partition ids
          vol.partition_id = ::Storage::ID_ESP
          vol.min_disk_size = DiskSize.MiB(33)
          vol.max_disk_size = DiskSize.unlimited
          vol.desired_disk_size = DiskSize.MiB(500)
          vol.can_live_on_logical_volume = false
          vol.max_start_offset = DiskSize.TiB(2)
        end
        vol
      end

      def reusable_efi
        @reusable_efi = biggest_efi_in_root_device || biggest_efi
      end

      def biggest_efi_in_root_device
        biggest_partition(disk_analyzer.efi_partitions[settings.root_device])
      end

      def biggest_efi
        biggest_partition(disk_analyzer.efi_partitions.values.flatten)
      end

      def biggest_partition(partitions)
        return nil if partitions.nil? || partitions.empty?
        partitions.sort_by.with_index { |part, idx| [part.size, idx] }.last
      end
    end
  end
end
