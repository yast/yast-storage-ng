# Copyright (c) [2022] SUSE LLC
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
      # Widget for displaying the `Mount Options` column
      class MountOptions < Base
        # Constructor
        def initialize
          super()

          textdomain "storage"
        end

        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header
          _("Mount Options")
        end

        # @see Columns::Base#value_for
        #
        # @param device [Y2Storage::Device, Y2Storage::Filesystems::LegacyNfs]
        def value_for(device)
          return device.fstopt if legacy_nfs?(device)

          mount_point = mount_point_for(device)

          return "" unless mount_point

          mount_point.mount_options.join(",")
        end
      end
    end
  end
end
