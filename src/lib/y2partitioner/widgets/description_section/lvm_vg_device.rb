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
      # Description section with specific data about a LVM VG device
      #
      # FIXME: For historical reasons, there are two similar sections for LVM VG, see
      # {DescriptionSection::LvmVg}. Maybe both sections could be merged.
      class LvmVgDevice < Base
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
          _("Device:")
        end

        # @see DescriptionSection::Base#entries
        def entries
          [:device, :size]
        end

        # Entry data about the LVM VG name
        #
        # @return [String]
        def device_value
          format(_("Device: %s"), device.name)
        end

        # Entry data about the LVM VG size
        #
        # @return [String]
        def size_value
          format(_("Size: %s"), device.size.to_human_string)
        end
      end
    end
  end
end
