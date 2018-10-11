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

      def initialize(*args)
        super
        textdomain "storage"
      end

      # @see Base#needed_partitions
      def needed_partitions(target)
        raise Error if grub_in_mbr? && mbr_gap && !valid_mbr_gap?
        planned_partitions = super
        planned_partitions << grub_partition(target) if grub_partition_needed? && grub_partition_missing?
        planned_partitions
      end

      # Boot warnings in the current setup
      #
      # @return [Array<SetupError>]
      def warnings
        res = super

        if boot_ptable_type?(:gpt)
          res.concat(errors_on_gpt)
        else
          res.concat(errors_on_msdos)
        end

        res
      end

    protected

      # Whether the MBR gap is big enough
      #
      # @return [Boolean] true if the MBR gap is enough; false otherwise.
      def valid_mbr_gap?
        mbr_gap && mbr_gap >= GRUB_SIZE
      end

      def grub_partition_needed?
        boot_ptable_type?(:gpt) && grub_part_needed_in_gpt?
      end

      # Given the fact we are trying to boot from a GPT disk, whether a BIOS
      # BOOT partition is needed in the current setup
      #
      # This always returns true because the usage of such partition is the only
      # method encouraged and documented for Grub2 in a legacy boot environment.
      # https://www.gnu.org/software/grub/manual/grub/grub.html#BIOS-installation
      #
      # In theory, the bootloader could work properly without BIOS BOOT if Grub2
      # is installed in a formatted partition. For that to work, the filesystem
      # must leave space for Grub at the beginning of the partition (like ExtX
      # does) or must support embedding Grub in the filesystem (like Btrfs).
      # But that's a fragile approach that is discouraged by the Grub2
      # developers. In any case, it will not work with XFS since it leaves
      # no space at the beginning of the partition. It wouldn't work for LVM,
      # encryption or RAID either.
      #
      # @return [Boolean] always true, rationale in the method documentation
      def grub_part_needed_in_gpt?
        true
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
        @grub_volume ||= volume_specification_for("grub")
      end

      # @return [Planned::Partition]
      def grub_partition(target)
        planned_partition = create_planned_partition(grub_volume, target)
        planned_partition.bootable = false
        planned_partition
      end

      # Boot errors when partition table is gpt
      #
      # @return [Array<SetupError>]
      def errors_on_gpt
        errors = []

        if grub_part_needed_in_gpt? && missing_partition_for?(grub_volume)
          errors << SetupError.new(missing_volume: grub_volume)
        end

        errors
      end

      # Boot errors when partition table is msdos
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
          "Boot disk has no partition table and it is not possible to boot from it." \
          "You can fix it by creating a partition table on the boot disk."
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
