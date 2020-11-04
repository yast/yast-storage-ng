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

require "cwm"
require "abstract_method"
require "y2partitioner/execute_and_redraw"

module Y2Partitioner
  module Widgets
    # Base class for a button that performs an action
    class ActionButton < CWM::PushButton
      include ExecuteAndRedraw

      # @macro seeAbstractWidget
      def handle
        execute_and_redraw { action.run }
      end

      # Action to perform when the button is clicked
      #
      # Derived classes must define this method.
      #
      # @return [Actions::Base]
      abstract_method :action
    end
  end
end
