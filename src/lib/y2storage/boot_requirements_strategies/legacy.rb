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
    # Strategy to calculate the boot requirements in a legacy system (x86
    # without EFI)
    class Legacy < Base
      GRUB_SIZE = DiskSize.KiB(256)
      GRUBENV_SIZE = DiskSize.KiB(1)

      def needed_partitions
        volumes = super
        volumes << grub_volume if grub_partition_needed? && grub_partition_missing?
        raise Error if grub_in_mbr? && mbr_gap < GRUB_SIZE

        volumes
      end

    protected

      def grub_partition_needed?
        # FIXME: so far we don't create partition tables, so we just analyze
        # the existing one.
        root_ptable_type?(:gpt)
      end

      def grub_partition_missing?
        partitions = disk_analyzer.grub_partitions[settings.root_device]
        partitions.nil? || partitions.empty?
      end

      def grub_in_mbr?
        # FIXME: see note above about existing partition tables
        root_ptable_type?(:msdos) && !btrfs_without_lvm?
      end

      def btrfs_without_lvm?
        settings.root_filesystem_type == ::Storage::FsType_BTRFS && !settings.use_lvm
      end

      def boot_partition_needed?
        grub_in_mbr? && settings.use_lvm && mbr_gap < GRUB_SIZE + GRUBENV_SIZE
      end

      def mbr_gap
        disk_analyzer.mbr_gap[settings.root_device]
      end

      def grub_volume
        vol = PlannedVolume.new(nil)
        # only required on GPT
        vol.partition_id = ::Storage::ID_BIOS_BOOT
        vol.min_disk_size = DiskSize.KiB(256)
        vol.max_disk_size = DiskSize.MiB(8)
        vol.desired_disk_size = DiskSize.MiB(1)
        vol.align = :keep_size
        vol.bootable = false
        vol.can_live_on_logical_volume = false
        vol
      end
    end
  end
end
