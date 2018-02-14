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
      def errors
        errors = super

        if missing_partition_for?(efi_volume)
          errors << SetupError.new(missing_volume: efi_volume)
        end

        errors
      end

    protected

      MIN_SIZE = DiskSize.MiB(33).freeze
      DESIRED_SIZE = DiskSize.MiB(500).freeze
      MAX_SIZE = DiskSize.MiB(500).freeze

      def efi_missing?
        free_mountpoint?("/boot/efi")
      end

      # @return [VolumeSpecification]
      def efi_volume
        return @efi_volume unless @efi_volume.nil?

        @efi_volume = VolumeSpecification.new({})
        @efi_volume.mount_point = "/boot/efi"
        @efi_volume.fs_types = [Filesystems::Type::VFAT]
        @efi_volume.fs_type = Filesystems::Type::VFAT
        @efi_volume.min_size = MIN_SIZE
        @efi_volume.desired_size = DESIRED_SIZE
        @efi_volume.max_size = MAX_SIZE
        @efi_volume
      end

      # @return [Planned::Partition]
      def efi_partition(target)
        planned_partition = create_planned_partition(efi_volume, target)

        # Partition is planned with a specific id (although it is not strictly required)
        planned_partition.partition_id = PartitionId::ESP

        if reusable_efi
          planned_partition.reuse = reusable_efi.name
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
