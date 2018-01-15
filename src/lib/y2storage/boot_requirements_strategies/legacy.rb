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

module Y2Storage
  module BootRequirementsStrategies
    # Strategy to calculate the boot requirements in a legacy system (x86 without EFI)
    class Legacy < Base
      GRUB_SIZE = DiskSize.KiB(256)
      GRUBENV_SIZE = DiskSize.KiB(1)

      # @see Base#needed_partitions
      def needed_partitions(target)
        raise Error if grub_in_mbr? && mbr_gap && !valid_mbr_gap?
        planned_partitions = super
        planned_partitions << grub_partition(target) if grub_partition_needed? && grub_partition_missing?
        planned_partitions
      end

      # Boot errors in the current setup
      #
      # @return [Array<SetupError>]
      def errors
        errors = super

        if root_filesystem_missing?
          errors << unknown_boot_disk_error
        elsif boot_partition_table_missing?
          errors << unknown_boot_partition_table_error
        elsif grub_partition_needed?
          errors += errors_on_gpt
        else
          errors += errors_on_msdos
        end

        errors
      end

    protected

      # Whether the boot disk has not partition table
      #
      # @return [Boolean] true if boot disk does not have partition table;
      #   false otherwise.
      def boot_partition_table_missing?
        boot_disk.partition_table.nil?
      end

      # Whether the MBR gap is big enough
      #
      # @return [Boolean] true if the MBR gap is enough; false otherwise.
      def valid_mbr_gap?
        mbr_gap && mbr_gap >= GRUB_SIZE
      end

      # FIXME: Bootloader could work properly without BIOS BOOT when the
      # partition supports embedding or it is possible to boot from the
      # partition. For example, for EXT filesystem it is possible to boot
      # from the partition, and grub2 can be embedded into the partition
      # when BTRFS is used. For LVM or RAID it is not possible to neither
      # embed nor boot from the partition.
      #
      # (gpt && (lvm || raid || encrypted)) || (gpt  && !ext && !btrfs)
      def grub_partition_needed?
        boot_ptable_type?(:gpt)
      end

      def grub_partition_missing?
        # We don't check if the planned partition is in the boot disk,
        # whoever created it is in control of the details
        current_devices = analyzer.planned_devices + boot_disk.partitions
        current_devices.none? { |d| d.match_volume?(grub_volume) }
      end

      def grub_in_mbr?
        boot_ptable_type?(:msdos) && !plain_btrfs?
      end

      def plain_btrfs?
        btrfs_without_lvm? && btrfs_without_software_raid? && btrfs_without_encryption?
      end

      def btrfs_without_lvm?
        btrfs_root? && !root_in_lvm?
      end

      # Whether the root filesystem is a BTRFS over a software raid
      #
      # @return [Boolean] true if it is a BTRFS over a software raid; false otherwise.
      def btrfs_without_software_raid?
        btrfs_root? && !root_in_software_raid?
      end

      def btrfs_without_encryption?
        btrfs_root? && !encrypted_root?
      end

      def boot_partition_needed?
        grub_in_mbr? && valid_mbr_gap? && mbr_gap < GRUB_SIZE + GRUBENV_SIZE
      end

      def mbr_gap
        boot_disk.mbr_gap
      end

      # @return [VolumeSpecification]
      def grub_volume
        return @grub_volume unless @grub_volume.nil?

        @grub_volume = VolumeSpecification.new({})
        @grub_volume.min_size = DiskSize.KiB(256)
        @grub_volume.desired_size = DiskSize.MiB(1)
        @grub_volume.max_size = DiskSize.MiB(8)
        # Only required on GPT
        @grub_volume.partition_id = PartitionId::BIOS_BOOT
        @grub_volume
      end

      # @return [Planned::Partition]
      def grub_partition(target)
        planned_partition = create_planned_partition(grub_volume, target)
        planned_partition.align = :keep_size
        planned_partition.bootable = false
        planned_partition
      end

      # Boot errors when partition table is gpt
      #
      # @return [Array<SetupError>]
      def errors_on_gpt
        errors = []

        if missing_partition_for?(grub_volume)
          errors << SetupError.new(missing_volume: grub_volume)
        end

        errors
      end

      # Boor errors when partition table is msdos
      #
      # @return [Array<SetupError>]
      def errors_on_msdos
        errors = []

        if !valid_mbr_gap?
          errors << mbr_gap_error if !plain_btrfs?
        elsif boot_partition_needed? && missing_partition_for?(boot_volume)
          errors << SetupError.new(missing_volume: boot_volume)
        end

        errors
      end

      # Specific error when the boot disk has not partition table
      #
      # @return [SetupError]
      def unknown_boot_partition_table_error
        # TRANSLATORS: error message
        error_message = _(
          "Boot requirements cannot be determined because " \
          "boot disk has not partition table"
        )
        SetupError.new(message: error_message)
      end

      # Specific error when the MBR gap is small
      #
      # @return [SetupError]
      def mbr_gap_error
        # TRANSLATORS: error message
        error_message = _("MBR gap size is not enough to correctly install bootloader")
        SetupError.new(message: error_message)
      end
    end
  end
end
