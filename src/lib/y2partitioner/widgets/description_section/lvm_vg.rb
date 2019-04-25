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

module Y2Partitioner
  module Widgets
    module DescriptionSection
      # Description section with specific data about a LVM VG
      class LvmVg < Base
        # Constructor
        #
        # @param device [Y2Storage::LvmVg]
        def initialize(device)
          textdomain "storage"

          super
        end

      private

        # @see DescriptionSection::Base#title
        def title
          # TRANSLATORS: title for section about LVM VG details
          _("LVM:")
        end

        # @see DescriptionSection::Base#entries
        def entries
          [:pe_size]
        end

        # Entry data about the volume group extent size
        #
        # @return [String]
        def pe_size_value
          # TRANSLATORS: Volume group extent size information, where %s is replaced by
          # a size (e.g., 8 KiB)
          format(_("PE Size: %s"), device.extent_size.to_human_string)
        end
      end
    end
  end
end
