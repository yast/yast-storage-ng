# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

module Y2Partitioner
  module Actions
    # Special action that makes possible to jump in the UI to any given tab of a
    # device page
    class GoToDeviceTab
      # @param device [Y2Storage::Device] device to visualize
      # @param pager [CWM::TreePager] general pager used to navigate through the
      #   partitioner
      # @param tab_label [String] label of the tab to open in the device page
      def initialize(device, pager, tab_label)
        @device = device
        @pager = pager
        @tab_label = tab_label
      end

      # If a page for the device is found, selects the given page and tab as the
      # initial point for the next redrawing.
      #
      # @return [nil, Symbol] :finish if it's possible to jump to the device
      #   page
      def run
        target_page = pager.device_page(device)
        return nil unless target_page

        # First, pretend the user visited the device and then the tab...
        state = UIState.instance
        state.go_to_tree_node(target_page)
        state.switch_to_tab(tab_label)

        # ...then trigger a redraw
        :finish
      end

    protected

      # @return [Y2Storage::Device] see {#initialize}
      attr_reader :device

      # @return [CWM::TreePager] see {#initialize}
      attr_reader :pager

      # @return [String] see {#initialize}
      attr_reader :tab_label
    end
  end
end
