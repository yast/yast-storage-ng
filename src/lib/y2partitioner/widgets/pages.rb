# encoding: utf-8

# Copyright (c) [2017-2019] SUSE LLC
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

module Y2Partitioner
  module Widgets
    # Namespace to group the different subclasses of CWM::Page used to represent
    # every one of the partitioner screens
    module Pages
    end
  end
end

require "y2partitioner/widgets/pages/system.rb"
require "y2partitioner/widgets/pages/disks.rb"
require "y2partitioner/widgets/pages/disk.rb"
require "y2partitioner/widgets/pages/partition.rb"
require "y2partitioner/widgets/pages/stray_blk_device.rb"
require "y2partitioner/widgets/pages/lvm.rb"
require "y2partitioner/widgets/pages/lvm_vg.rb"
require "y2partitioner/widgets/pages/lvm_lv.rb"
require "y2partitioner/widgets/pages/md_raids.rb"
require "y2partitioner/widgets/pages/md_raid.rb"
require "y2partitioner/widgets/pages/nfs_mounts.rb"
require "y2partitioner/widgets/pages/bcache.rb"
require "y2partitioner/widgets/pages/bcaches.rb"
require "y2partitioner/widgets/pages/btrfs_filesystems.rb"
require "y2partitioner/widgets/pages/btrfs.rb"
require "y2partitioner/widgets/pages/device_graph.rb"
require "y2partitioner/widgets/pages/summary.rb"
require "y2partitioner/widgets/pages/settings.rb"
