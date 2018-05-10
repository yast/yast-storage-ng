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
require "yast/i18n"
require "cwm/dialog"
require "y2partitioner/widgets/summary_text"
require "y2partitioner/actions/quit_partitioner"

Yast.import "Label"

module Y2Partitioner
  module Dialogs
    # Dialog to show the summary of changes performed by the user
    class Summary < CWM::Dialog
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

      def next_button
        Yast::Label.FinishButton
      end

      # @see Actions::QuitPartitioner#quit?
      #
      # @return [Boolean] it aborts if returns true
      def abort_handler
        Actions::QuitPartitioner.new.quit?
      end
    end
  end
end
