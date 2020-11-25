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

require "yast"
require "y2partitioner/widgets/columns/disk_size"

module Y2Partitioner
  module Widgets
    module Columns
      # Widget for displaying the `Referenced Size Limit` column
      class BtrfsRferLimit < DiskSize
        # Constructor
        def initialize
          textdomain "storage"
        end

        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header - Max size of the referenced space
          # of a subvolume
          Right(_("Size Limit"))
        end

        private

        # Returns the limit of the referenced space for the given device, if possible
        #
        # @param device [Y2Storage::Device]
        # @return [Y2Stoorage::DiskSize, nil] a disk size object when possible; nil otherwise
        def device_size(device)
          return nil unless device.respond_to?(:referenced_limit)
          return nil if device.referenced_limit.unlimited?

          device.referenced_limit
        end
      end
    end
  end
end
