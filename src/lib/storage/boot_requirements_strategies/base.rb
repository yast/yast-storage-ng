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

module Yast
  module Storage
    module BootRequirementsStrategies
      # Base class for the strategies used to calculate the boot partitioning
      # requirements
      class Base
        include Yast::Logger

        def initialize(settings, disk_analyzer)
          @settings = settings
          @disk_analyzer = disk_analyzer
        end

        def needed_partitions
          volumes = PlannedVolumesList.new
          volumes << boot_volume if boot_partition_needed?
          volumes
        end

      protected

        attr_reader :settings
        attr_reader :disk_analyzer

        def boot_partition_needed?
          settings.use_lvm # || settings.encrypted
        end

        def boot_volume
          vol = PlannedVolume.new("/boot", ::Storage::FsType_EXT4)
          vol.min_size = DiskSize.MiB(100)
          vol.max_size = DiskSize.MiB(500)
          vol.desired_size = DiskSize.MiB(200)
          vol.can_live_on_logical_volume = false
          vol
        end
      end
    end
  end
end
