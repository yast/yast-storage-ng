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

require "y2partitioner/ui_state"

module Y2Partitioner
  module Widgets
    # Mixin for widgets that need to execute an action that can modify the
    # devicegraph and, as a result, need to redraw the Partitioner interface
    module ExecuteAndRedraw
      # Saves the status of the navigation tree, executes the passed block and
      # transforms the result of that block into something the main loop of the
      # Partitioner can understand
      #
      # Expects a block that must return :finish to force a reload or any other
      # value to force a step back.
      #
      # @return [:redraw, nil]
      def execute_and_redraw
        UIState.instance.save_open_items
        redraw_result(yield)
      end

      # By default, it returns :redraw when the action is performed; nil otherwise
      #
      # @return [:redraw, nil]
      def redraw_result(result)
        result == :finish ? :redraw : nil
      end
    end
  end
end
