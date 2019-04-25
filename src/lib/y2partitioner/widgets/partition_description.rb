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

require "y2partitioner/widgets/device_description"
require "y2partitioner/widgets/description_section/partition"
require "y2partitioner/widgets/description_section/filesystem"

module Y2Partitioner
  module Widgets
    # Description for a partition
    class PartitionDescription < DeviceDescription
    private

      # @see DeviceDescription#sections
      def sections
        [
          DescriptionSection::Partition.new(device),
          DescriptionSection::Filesystem.new(device.filesystem)
        ]
      end
    end
  end
end
