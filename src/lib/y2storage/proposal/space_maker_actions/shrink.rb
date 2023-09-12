# Copyright (c) [2023] SUSE LLC
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

require "y2storage/proposal/space_maker_actions/base"

module Y2Storage
  module Proposal
    module SpaceMakerActions
      # Action for resizing a given partition
      #
      # @see Base
      class Shrink < Base
        # @return [DiskSize] size of the space to substract ideally
        attr_accessor :shrink_size

        # Reduces the size of the target partition
        #
        # If possible, it reduces the size of the partition by {#shrink_size}.
        # Otherwise, it reduces the size as much as possible.
        #
        # This method does not take alignment into account.
        #
        # @param devicegraph [Devicegraph]
        # @return [Array<Integer>] always empty, resizing should not cause deletion of devices
        def shrink(devicegraph)
          partition = devicegraph.find_device(sid)
          shrink_partition(partition)
          []
        end

        protected

        # @param partition [Partition]
        def shrink_partition(partition)
          target = shrink_size.unlimited? ? DiskSize.zero : partition.size - shrink_size
          # Explicitly avoid alignment to keep current behavior (to be reconsidered)
          partition.resize(target, align_type: nil)
        end
      end
    end
  end
end
