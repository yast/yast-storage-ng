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
require "y2partitioner/widgets/lvm_lv_attributes"

module Y2Partitioner
  module Widgets
    module Columns
      # Widget for displaying the information about LVM LV stripes in the `Stripes` column
      class Stripes < Base
        include LvmLvAttributes

        # Constructor
        def initialize
          super
          textdomain "storage"
        end

        # @see Columns::Base#title
        def title
          # TRANSLATORS: table header, number and size of LVM LV stripes
          _("Stripes")
        end

        # @see Columns::Base#value_for
        def value_for(device)
          return "" unless device.respond_to?(:stripes)

          stripes_info(device)
        end
      end
    end
  end
end
