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
    # Strategy to calculate boot requirements in systems using PReP
    class PReP < Base
      # @see Base#needed_partitions
      def needed_partitions(target)
        planned_partitions = super
        if prep_partition_needed? && prep_partition_missing?
          # Use unshift so PReP goes first (bsc#1076851)
          planned_partitions.unshift(prep_partition(target))
        end
        planned_partitions
      end

      # Boot warnings in the current setup
      #
      # @return [Array<SetupError>]
      def warnings
        res = super

        if prep_partition_needed? && missing_partition_for?(prep_volume)
          res << SetupError.new(missing_volume: prep_volume)
        end

        if boot_partition_needed? && missing_partition_for?(boot_volume)
          res << SetupError.new(missing_volume: boot_volume)
        end

        res
      end

    protected

      def boot_partition_needed?
        # PowerNV uses it's own firmware instead of Grub stage 1, but other
        # PPC systems use regular Grub. Just use the default logic for those.
        return super unless arch.ppc_power_nv?

        # We cannot ensure the mentioned firmware can handle technologies like
        # LVM, MD or LUKS, so propose a separate /boot partition for those cases
        root_in_lvm? || root_in_software_raid? || encrypted_root?
      end

      def prep_partition_needed?
        # no need of PReP partition in OPAL/PowerNV/Bare metal
        !arch.ppc_power_nv?
      end

      def prep_partition_missing?
        # We don't check if the planned PReP partition is in the boot disk,
        # whoever created it is in control of the details
        current_devices = analyzer.planned_devices + boot_disk.partitions
        current_devices.none? { |d| d.match_volume?(prep_volume) }
      end

      # @return [VolumeSpecification]
      def prep_volume
        return @prep_volume unless @prep_volume.nil?

        @prep_volume = VolumeSpecification.new({})
        # So far we are always using msdos partition ids
        @prep_volume.partition_id = PartitionId::PREP
        # Grub2 with all the modules we could possibly use (LVM, LUKS, etc.)
        # is slightly bigger than 1MiB
        @prep_volume.min_size = DiskSize.MiB(2)
        @prep_volume.desired_size = DiskSize.MiB(4)
        @prep_volume.max_size = DiskSize.MiB(8)
        # TODO: We have been told that PReP must be one of the first 4
        # partitions, ideally the first one. But we have not found any
        # rationale/evidence. Not implementing that for the time being
        @prep_volume
      end

      # @return [Planned::Partition]
      def prep_partition(target)
        planned_partition = create_planned_partition(prep_volume, target)
        planned_partition.bootable = true
        planned_partition
      end

      def arch
        @arch ||= StorageManager.instance.arch
      end
    end
  end
end
