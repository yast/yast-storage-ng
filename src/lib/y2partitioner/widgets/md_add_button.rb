# Copyright (c) [2017] SUSE LLC
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
require "cwm"
require "y2partitioner/actions/add_md"
require "y2partitioner/widgets/execute_and_redraw"

module Y2Partitioner
  module Widgets
    # Button for openng a wizard to add a new MD array
    class MdAddButton < CWM::PushButton
      include ExecuteAndRedraw

      # Constructor
      def initialize
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to add a MD Raid
        _("Add RAID...")
      end

      # @macro seeAbstractWidget
      # @see Actions::AddMd
      def handle
        execute_and_redraw { Actions::AddMd.new.run }
      end
    end
  end
end
