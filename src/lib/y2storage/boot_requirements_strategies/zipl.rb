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
    # Strategy to calculate boot requirements in systems using ZIPL
    class ZIPL < Base
      def needed_partitions
        raise Error unless supported_root_disk?
        PlannedVolumesList.new([zipl_volume])
      end

    protected

      def supported_root_disk?
        return false unless root_disk
        if root_disk.dasd?
          return false if root_disk.dasd_type == ::Storage::DASDTYPE_FBA
          return false if root_disk.dasd_format == ::Storage::DASDF_LDL
          # TODO: DIAG disks (whatever they are) are not supported either
        end
        true
      end

      def zipl_volume
        vol = PlannedVolume.new("/boot/zipl", ::Storage::FsType_EXT2)
        vol.disk = root_disk.name
        vol.min_disk_size = DiskSize.MiB(100)
        vol.max_disk_size = DiskSize.GiB(1)
        vol.desired_disk_size = DiskSize.MiB(200)
        vol.plain_partition = true
        vol
      end
    end
  end
end
