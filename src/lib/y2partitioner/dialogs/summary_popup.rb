# Copyright (c) [2018-2020] SUSE LLC
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
require "yast/i18n"
require "y2partitioner/dialogs/popup"
require "y2partitioner/widgets/summary_text"
require "y2partitioner/actions/quit_partitioner"

Yast.import "Label"

module Y2Partitioner
  module Dialogs
    # Dialog to show the summary of changes performed by the user
    class SummaryPopup < Popup
      include Yast::I18n

      def initialize
        textdomain "storage"
      end

      def title
        _("Expert Partitioner: Summary")
      end

      def contents
        @contents ||= VBox(Widgets::SummaryText.new)
      end

      protected

      def buttons
        [ok_button]
      end

      def min_width
        65
      end
    end
  end
end
