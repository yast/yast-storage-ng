# Copyright (c) [2020] SUSE LLC
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
    # Namespace to group all widgets to render the content for an specific device table column
    module Columns
    end
  end
end

require "y2partitioner/widgets/columns/btrfs_exclusive"
require "y2partitioner/widgets/columns/btrfs_referenced"
require "y2partitioner/widgets/columns/btrfs_rfer_limit"
require "y2partitioner/widgets/columns/caching_device"
require "y2partitioner/widgets/columns/chunk_size"
require "y2partitioner/widgets/columns/device"
require "y2partitioner/widgets/columns/encrypted"
require "y2partitioner/widgets/columns/filesystem_label"
require "y2partitioner/widgets/columns/format"
require "y2partitioner/widgets/columns/mount_point"
require "y2partitioner/widgets/columns/pe_size"
require "y2partitioner/widgets/columns/raid_type"
require "y2partitioner/widgets/columns/region_end"
require "y2partitioner/widgets/columns/region_start"
require "y2partitioner/widgets/columns/size"
require "y2partitioner/widgets/columns/stripes"
require "y2partitioner/widgets/columns/type"
require "y2partitioner/widgets/columns/used_by"
require "y2partitioner/widgets/columns/uuid"
