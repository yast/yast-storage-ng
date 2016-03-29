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

require "yast"
require "storage/boot_requirements_strategies/base"
require "storage/planned_volume"
require "storage/planned_volumes_list"
require "storage/disk_size"

module Yast
  module Storage
    module BootRequirementsStrategies
      class UEFI < Base
        def needed_partitions
          volumes = super
          volumes << efi_volume if efi_partition_missing?
          volumes
        end

      protected

        def efi_partition_missing?
          disk_analyzer.efi_partitions.empty?
        end

        def efi_volume
          # TODO: we need to pass partition type somehow (EFI system partition, ID_GPT_BIOS (?))
          vol = PlannedVolume.new("/boot/efi", ::Storage::FsType_VFAT)
          vol.min_size = DiskSize.MiB(33)
          vol.max_size = DiskSize.unlimited
          vol.desired_size = DiskSize.MiB(500)
          vol.can_live_on_logical_volume = false
          # TODO: additional requirement - position below 2TB 
          vol
        end
      end
    end
  end
end
