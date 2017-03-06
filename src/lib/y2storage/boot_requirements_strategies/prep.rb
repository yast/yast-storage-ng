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
    # Strategy to calculate boot requirements in systems using PReP
    class PReP < Base
      def needed_partitions
        volumes = super
        volumes << prep_volume if prep_partition_needed? && prep_partition_missing?
        volumes
      end

    protected

      def boot_partition_needed?
        settings.use_lvm || settings.use_encryption
      end

      def prep_partition_needed?
        # no need of PReP partition in OPAL/PowerNV/Bare metal
        !arch.ppc_power_nv?
      end

      def prep_partition_missing?
        partitions = disk_analyzer.prep_partitions[settings.root_device]
        partitions.nil? || partitions.empty?
      end

      def prep_volume
        vol = PlannedVolume.new(nil)
        # So far we are always using msdos partition ids
        vol.partition_id = ::Storage::ID_PREP
        vol.min_disk_size = DiskSize.KiB(256)
        vol.max_disk_size = DiskSize.MiB(8)
        vol.desired_disk_size = DiskSize.MiB(1)
        # Make sure that alignment does not result in a too big partition
        vol.align = :keep_size
        vol.bootable = true
        vol.plain_partition = true
        # TODO: We have been told that PReP must be one of the first 4
        # partitions, ideally the first one. But we have not found any
        # rational/evidence. Not implementing that for the time being
        vol
      end

      def arch
        @arch ||= StorageManager.instance.arch
      end
    end
  end
end
