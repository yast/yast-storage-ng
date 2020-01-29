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

require "cwm/widget"
require "cwm/pager"
require "cwm/tree_pager"

module Y2Partitioner
  module Widgets
    module Pages
      # A base class for partitioner pages
      class Base < CWM::Page
        # Convenience method to identify a page and/or its status in {UIState}
        #
        # @note This has been added as a way to really avoid the dependency cycles between {UIState}
        # and actions due to Ruby requires in some pages. As {UIState} only needs a device sid or a
        # page label to make the work, let's pass the right one instead of the full object.
        #
        # @see UIState#select_page
        #
        # @return [String, Integer] a device sid if possible; the page label otherwise
        def id
          if respond_to?(:device)
            device.sid
          else
            label
          end
        end

        # The full path to reach the page within the tree
        #
        # Useful to know where to place the user after redrawing the UI. See
        # {Y2Partitioner::UIState::PageStatus#candidate_pages}
        #
        # @return [Array<String, Integer>]
        def parents
          [device_page_parents, id].compact
        end

        private

        # The path to the device, if any
        #
        # @return [String, Integer, nil]
        def device_page_parents
          return nil unless respond_to?(:device)

          if device.is?(:partition)
            device.partitionable.sid
          elsif device.is?(:lvm_lv)
            device.lvm_vg.sid
          else
            section
          end
        end

        # The section which the page belongs
        #
        # @return [String, nil]
        def section
          nil
        end
      end
    end
  end
end
