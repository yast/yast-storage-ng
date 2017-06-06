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
      def needed_partitions(target)
        raise Error unless supported_boot_disk?
        [zipl_partition(target)]
      end

    protected

      def supported_boot_disk?
        return false unless boot_disk
        if boot_disk.is?(:dasd)
          return false if boot_disk.dasd_type.is?(:fba)
          return false if boot_disk.dasd_format.is?(:ldl)
          # TODO: DIAG disks (whatever they are) are not supported either
        end
        true
      end

      def zipl_partition(target)
        vol = Planned::Partition.new("/boot/zipl", Filesystems::Type::EXT2)
        vol.disk = boot_disk.name
        vol.min_size = target == :min ? DiskSize.MiB(100) : DiskSize.MiB(200)
        vol.max_size = DiskSize.GiB(1)
        vol
      end
    end
  end
end
