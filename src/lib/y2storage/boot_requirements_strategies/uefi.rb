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
      # @see Base#needed_partitions
      def needed_partitions(target)
        planned_partitions = super
        planned_partitions << efi_partition(target) if efi_missing?
        planned_partitions
      end

      # Boot errors in the current setup
      #
      # @return [Array<SetupError>]
      def warnings
        res = super
        textdomain "storage"

        # EFI in RAID can work, but it is not much reliable. see bsc#1081578#c9
        if efi_in_md_raid1?
          msg = _("/boot/efi is inside MD RAID. In general it is discouraged to use this setup,
            but it can work.")
          res << SetupError.new(message: msg)
        # Missing EFI does not need to be a fatal (e.g. when boot from network).
        # User just has to not select grub2-efi bootloader.
        elsif missing_partition_for?(efi_volume)
          res << SetupError.new(missing_volume: efi_volume)
        end

        res
      end

    protected

      def efi_in_md_raid1?
        filesystem = devicegraph.filesystems.find { |f| f.mount_path == "/boot/efi" }
        return false unless filesystem

        raid = filesystem.ancestors.find { |dev| dev.is?(:software_raid) }
        return false unless raid

        return raid.md_level.is?(:raid1)
      end

      def efi_missing?
        free_mountpoint?("/boot/efi")
      end

      # @return [VolumeSpecification]
      def efi_volume
        @efi_volume ||= volume_specification_for("/boot/efi")
      end

      # @return [Planned::Partition]
      def efi_partition(target)
        planned_partition = create_planned_partition(efi_volume, target)

        # Partition is planned with a specific id (although it is not strictly required)
        planned_partition.partition_id = PartitionId::ESP

        if reusable_efi
          planned_partition.reuse_name = reusable_efi.name
        else
          planned_partition.max_start_offset = DiskSize.TiB(2)
        end

        planned_partition
      end

      def reusable_efi
        @reusable_efi = biggest_efi_in_boot_device || biggest_efi
      end

      def biggest_efi_in_boot_device
        biggest_partition(suitable_efi_partitions(boot_disk))
      end

      def biggest_efi
        efi_partitions = devicegraph.disk_devices.map { |d| suitable_efi_partitions(d) }.flatten
        biggest_partition(efi_partitions)
      end

      def suitable_efi_partitions(device)
        device.partitions.select do |partition|
          partition.match_volume?(efi_volume, exclude: :mount_point) &&
            partition.id == PartitionId::ESP
        end
      end

      def biggest_partition(partitions)
        return nil if partitions.nil? || partitions.empty?
        partitions.sort_by.with_index { |part, idx| [part.size, idx] }.last
      end
    end
  end
end
