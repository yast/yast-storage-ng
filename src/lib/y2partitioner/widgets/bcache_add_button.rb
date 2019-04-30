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
require "cwm"
require "y2partitioner/actions/add_bcache"
require "y2partitioner/widgets/execute_and_redraw"

module Y2Partitioner
  module Widgets
    # Button for opening a wizard to add a new Bcache device
    class BcacheAddButton < CWM::PushButton
      include ExecuteAndRedraw

      # Constructor
      def initialize
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to add a new Bcache device
        _("Add Bcache...")
      end

      # @macro seeAbstractWidget
      # @see Actions::AddBcache
      def handle
        execute_and_redraw { Actions::AddBcache.new.run }
      end
    end
  end
end
