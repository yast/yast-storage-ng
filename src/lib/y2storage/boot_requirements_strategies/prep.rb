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
    # Strategy to calculate boot requirements in systems using PReP
    class PReP < Base
      def needed_partitions(target)
        volumes = super
        volumes << prep_partition(target) if prep_partition_needed? && prep_partition_missing?
        volumes
      end

    protected

      def boot_partition_needed?
        root_in_lvm? || encrypted_root?
      end

      def prep_partition_needed?
        # no need of PReP partition in OPAL/PowerNV/Bare metal
        !arch.ppc_power_nv?
      end

      def prep_partition_missing?
        partitions = boot_disk.prep_partitions
        partitions.nil? || partitions.empty?
      end

      def prep_partition(target)
        vol = Planned::Partition.new(nil)
        # So far we are always using msdos partition ids
        vol.partition_id = PartitionId::PREP
        vol.min_size = target == :min ? DiskSize.KiB(256) : DiskSize.MiB(1)
        vol.max_size = DiskSize.MiB(8)
        # Make sure that alignment does not result in a too big partition
        vol.align = :keep_size
        vol.bootable = true
        # TODO: We have been told that PReP must be one of the first 4
        # partitions, ideally the first one. But we have not found any
        # rationale/evidence. Not implementing that for the time being
        vol
      end

      def arch
        @arch ||= StorageManager.instance.arch
      end
    end
  end
end
