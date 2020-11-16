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
require "y2partitioner/widgets/columns/base"

module Y2Partitioner
  module Widgets
    module Columns
      # Base class for all the columns that need to display a DiskSize
      class DiskSize < Base
        # @!method device_size(device)
        #   Size to be used in {#value_for}
        #
        #   This abstract method must be implemented by the descending classes
        #
        #   @param device [Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry] see {#value_for}
        #   @return [Y2Storage::DiskSize, nil] size to display or nil for a blank cell
        abstract_method :device_size

        # @see Columns::Base#value_for
        def value_for(device)
          size = device_size(device)

          return "" unless size

          cell(size.to_human_string, sort_key(size.to_i.to_s))
        end
      end
    end
  end
end
