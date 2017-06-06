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
require "y2storage/partition_id"
require "y2storage/filesystems/type"

module Y2Storage
  module BootRequirementsStrategies
    # Strategy to calculate boot requirements in UEFI systems
    class UEFI < Base
      def needed_partitions(target)
        volumes = super
        volumes << efi_partition(target)
        volumes
      end

    protected

      def efi_partition(target)
        vol = Planned::Partition.new("/boot/efi", Filesystems::Type::VFAT)
        if reusable_efi
          vol.reuse = reusable_efi.name
        else
          vol.partition_id = PartitionId::ESP
          vol.min_size = target == :min ? DiskSize.MiB(33) : DiskSize.MiB(500)
          vol.max_size = DiskSize.unlimited
          vol.max_start_offset = DiskSize.TiB(2)
        end
        vol
      end

      def reusable_efi
        @reusable_efi = biggest_efi_in_boot_device || biggest_efi
      end

      def biggest_efi_in_boot_device
        biggest_partition(boot_disk.efi_partitions)
      end

      def biggest_efi
        efi_parts = devicegraph.disks.map(&:efi_partitions).flatten
        biggest_partition(efi_parts)
      end

      def biggest_partition(partitions)
        return nil if partitions.nil? || partitions.empty?
        partitions.sort_by.with_index { |part, idx| [part.size, idx] }.last
      end
    end
  end
end
