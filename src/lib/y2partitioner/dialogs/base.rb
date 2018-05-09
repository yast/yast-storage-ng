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

require "cwm/dialog"

module Y2Partitioner
  module Dialogs
    # In general, no dialog in the Expert Partitioner should show "abort" button,
    # so all dialogs can use this base class to label abort button as "Cancel".
    #
    # Only main dialog shows the abort button (in a running system).
    class Base < CWM::Dialog
      def abort_button
        Yast::Label.CancelButton
      end
    end
  end
end
