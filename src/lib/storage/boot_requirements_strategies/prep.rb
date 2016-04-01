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
      # Strategy to calculate boot requirements in systems using PReP
      class PReP < Base
        def needed_partitions
          volumes = super
          volumes << prep_volume if prep_partition_missing?
          volumes
        end

      protected

        def prep_partition_missing?
          true	# #prep_partitions not implemented yet
          # disk_analyzer.prep_partitions.empty?
        end

        def prep_volume
          # TODO: we need to pass partition type somehow (PReP partition, ID_PPC_PREP, ID_GPT_PREP)
          # TODO: hoe to really pass 'no mount point' and 'no fs'?
          vol = PlannedVolume.new("", ::Storage::FsType_UNKNOWN)
          vol.min_size = DiskSize.MiB(1)
          vol.max_size = DiskSize.MiB(8)
          vol.desired_size = DiskSize.MiB(1)
          vol.can_live_on_logical_volume = false
          vol
        end
      end
    end
  end
end
