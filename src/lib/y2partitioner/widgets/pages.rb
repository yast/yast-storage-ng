# Copyright (c) [2017-2022] SUSE LLC
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

require "y2partitioner/widgets/pages/base"
require "y2partitioner/widgets/pages/system"
require "y2partitioner/widgets/pages/disks"
require "y2partitioner/widgets/pages/disk"
require "y2partitioner/widgets/pages/stray_blk_device"
require "y2partitioner/widgets/pages/lvm"
require "y2partitioner/widgets/pages/lvm_vg"
require "y2partitioner/widgets/pages/md_raids"
require "y2partitioner/widgets/pages/md_raid"
require "y2partitioner/widgets/pages/nfs_mounts"
require "y2partitioner/widgets/pages/nfs"
require "y2partitioner/widgets/pages/bcache"
require "y2partitioner/widgets/pages/bcaches"
require "y2partitioner/widgets/pages/btrfs_filesystems"
require "y2partitioner/widgets/pages/btrfs"
require "y2partitioner/widgets/pages/tmpfs_filesystems"
require "y2partitioner/widgets/pages/tmpfs"
