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

require "y2partitioner/dialogs/base"

module Y2Partitioner
  module Dialogs
    # Base class for dialogs that do not belong to a wizard. They are intended to be used in a single
    # step action.
    class SingleStep < Base
      # Always opens a new dialog (do not override the current wizard content). Otherwise, the main
      # wizard (which contains the left tree, menu, etc) should be refreshed even though the user cancels
      # the current action.
      def should_open_dialog?
        true
      end

      # Hides abort button
      def abort_button
        ""
      end

      def next_button
        Yast::Label.AcceptButton
      end

      def back_button
        Yast::Label.CancelButton
      end
    end
  end
end
