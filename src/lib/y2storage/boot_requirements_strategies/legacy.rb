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

module Y2Storage
  module BootRequirementsStrategies
    # Strategy to calculate the boot requirements in a legacy system (x86
    # without EFI)
    class Legacy < Base
      GRUB_SIZE = DiskSize.KiB(256)
      GRUBENV_SIZE = DiskSize.KiB(1)

      def needed_partitions(target)
        volumes = super
        volumes << grub_partition(target) if grub_partition_needed? && grub_partition_missing?
        raise Error if grub_in_mbr? && mbr_gap && mbr_gap < GRUB_SIZE

        volumes
      end

    protected

      def grub_partition_needed?
        boot_ptable_type?(:gpt)
      end

      def grub_partition_missing?
        partitions = boot_disk.grub_partitions
        partitions.nil? || partitions.empty?
      end

      def grub_in_mbr?
        boot_ptable_type?(:msdos) && !plain_btrfs?
      end

      def plain_btrfs?
        btrfs_without_lvm? && btrfs_without_encryption?
      end

      def btrfs_without_lvm?
        btrfs_root? && !root_in_lvm?
      end

      def btrfs_without_encryption?
        btrfs_root? && !encrypted_root?
      end

      def boot_partition_needed?
        grub_in_mbr? && mbr_gap && mbr_gap < GRUB_SIZE + GRUBENV_SIZE
      end

      def mbr_gap
        boot_disk.mbr_gap
      end

      def grub_partition(target)
        vol = Planned::Partition.new(nil)
        # only required on GPT
        vol.partition_id = PartitionId::BIOS_BOOT
        vol.min_size = target == :min ? DiskSize.KiB(256) : DiskSize.MiB(1)
        vol.max_size = DiskSize.MiB(8)
        vol.align = :keep_size
        vol.bootable = false
        vol
      end
    end
  end
end
