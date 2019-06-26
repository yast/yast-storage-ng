# Copyright (c) [2019] SUSE LLC
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

require "y2partitioner/widgets/description_section/blk_device"

module Y2Partitioner
  module Widgets
    module DescriptionSection
      # Description section with specific data about a partition
      class Partition < BlkDevice
        # Constructor
        #
        # @param device [Y2Storage::Partition]
        def initialize(device)
          textdomain "storage"

          super
        end

        private

        # @see DescriptionSection::BlkDevice#entries
        def entries
          super + [:partition_id]
        end

        # Entry data about the partition id
        #
        # @return [String]
        def partition_id_value
          # TRANSLATORS: Partition Identifier, where %s is replaced by the partition id (e.g., SWAP)
          format(_("Partition ID: %s"), device.id.to_human_string)
        end
      end
    end
  end
end
