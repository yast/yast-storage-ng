# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
  # Namespace to group all the dialogs of the expert partitioner
  module Dialogs
  end
end

require "y2partitioner/dialogs/popup"
require "y2partitioner/dialogs/encrypt_password"
require "y2partitioner/dialogs/main"
require "y2partitioner/dialogs/btrfs_subvolume"
require "y2partitioner/dialogs/md"
require "y2partitioner/dialogs/md_options"
require "y2partitioner/dialogs/partition_type"
require "y2partitioner/dialogs/btrfs_subvolumes"
require "y2partitioner/dialogs/fstab_options"
require "y2partitioner/dialogs/partition_role"
require "y2partitioner/dialogs/partition_size"
require "y2partitioner/dialogs/partition_table_type"
require "y2partitioner/dialogs/lvm_lv_size"
require "y2partitioner/dialogs/lvm_lv_info"
require "y2partitioner/dialogs/format_and_mount"
require "y2partitioner/dialogs/mkfs_options"
