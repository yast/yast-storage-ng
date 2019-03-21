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

Yast.import "Arch"

module Y2Storage
  module BootRequirementsStrategies
    # Strategy to calculate boot requirements in UEFI systems
    class UEFI < Base
      def initialize(*args)
        textdomain "storage"
        super
      end

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
        res_new = []

        res_new << esp_encrypted_error if encrypted_esp?
        res_new << esp_lvm_error if esp_in_lvm?

        # EFI in RAID can work, but it is not much reliable.
        # See bsc#1081578#c9, FATE#322485, FATE#314829
        # - RAID metadata must be somewhere where it will not interfere with UEFI reading
        #   the disk. libstorage-ng currently uses "mdadm --metadata=1.0" which is OK
        # - The partition boot flag must be on
        # - The partition RAID flag must be on (but setting it resets the boot flag)
        res_new << esp_raid_error if esp_in_software_raid?

        # Missing EFI does not need to be a fatal (e.g. when boot from network).
        # User just has to not select grub2-efi bootloader.
        res_new << esp_missing_warning if res_new.empty? && missing_partition_for?(efi_volume)

        res + res_new
      end

    protected

      def esp_encrypted_error
        msg = _("EFI System Partition cannot be encrypted.")
        SetupError.new(message: msg)
      end

      def esp_lvm_error
        msg = _("EFI System Partition cannot be on LVM.")
        SetupError.new(message: msg)
      end

      def esp_raid_error
        if esp_in_software_raid1?
          msg =
            _(
              "EFI System Partition is on a software RAID1. " \
              "That setup is not guaranteed to boot in all cases."
            )
        else
          msg = _("EFI System Partition cannot be on software RAID.")
        end
        SetupError.new(message: msg)
      end

      def esp_missing_warning
        SetupError.new(missing_volume: efi_volume)
      end

      def efi_missing?
        free_mountpoint?("/boot/efi")
      end

      # @return [VolumeSpecification]
      def efi_volume
        if @efi_volume.nil?
          @efi_volume = volume_specification_for("/boot/efi")
          limit_volume_size_to_min(@efi_volume) if Yast::Arch.aarch64 # bsc#1119318
        end
        @efi_volume
      end

      def limit_volume_size_to_min(vol)
        vol.max_size = vol.min_size
        vol.desired_size = vol.min_size
        vol
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
          planned_partition.disk = boot_disk.name
        end

        planned_partition
      end

      def reusable_efi
        @reusable_efi = biggest_efi_in_boot_device
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
