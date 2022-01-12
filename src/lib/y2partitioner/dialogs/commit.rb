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

require "yast"
require "yast/i18n"
require "cwm/dialog"
require "y2partitioner/widgets/commit_actions"

Yast.import "Label"

module Y2Partitioner
  module Dialogs
    # Dialog to show the progress of the storage changes while they are being applied
    class Commit < CWM::Dialog
      include Yast::I18n

      def initialize
        super()
        textdomain "storage"
      end

      def title
        _("Applying Changes to the System")
      end

      def contents
        @contents ||= VBox(commit_actions_widget)
      end

      # Does not show a back button
      def back_button
        ""
      end

      # Does not show an abort button
      def abort_button
        ""
      end

      # Shows next button with "Finish" label
      def next_button
        Yast::Label.FinishButton
      end

      private

      # Widget to show commit actions and progress bar
      #
      # @return [Widgets::CommitActions]
      def commit_actions_widget
        @commit_actions_widget ||= Widgets::CommitActions.new
      end
    end
  end
end
