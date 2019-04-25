# encoding: utf-8

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

require "y2partitioner/widgets/description_section/base"
require "y2partitioner/widgets/lvm_lv_attributes"

module Y2Partitioner
  module Widgets
    module DescriptionSection
      # Description section with specific data about a LVM LV device
      class LvmLv < Base
        include LvmLvAttributes

        # Constructor
        #
        # @param device [Y2Storage::LvmLv]
        def initialize(device)
          textdomain "storage"

          super
        end

      private

        # Required by mixin {LvmLvAttributes}
        alias_method :lvm_lv, :device

        # @see DescriptionSection::Base#title
        def title
          # TRANSLATORS: title for section about LVM LV details
          _("LVM:")
        end

        # @see DescriptionSection::Base#entries
        def entries
          [:stripes]
        end

        # Entry data about the stripes
        #
        # @see LvmLvAttributes
        #
        # @return [String]
        def stripes_value
          device_stripes
        end
      end
    end
  end
end
