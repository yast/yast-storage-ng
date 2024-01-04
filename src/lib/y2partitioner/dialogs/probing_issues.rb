# Copyright (c) [2021] SUSE LLC
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
require "y2partitioner/device_graphs"
require "y2partitioner/dialogs/popup"
require "y2storage/widgets/issues"

module Y2Partitioner
  module Dialogs
    # Dialog to show the probing issues detected in the system
    class ProbingIssues < Popup
      def initialize
        super
        textdomain "storage"
      end

      def title
        _("Issues Detected in the System")
      end

      def contents
        @contents ||= VBox(IssuesWidget.new)
      end

      private

      def buttons
        [ok_button]
      end

      def min_width
        65
      end

      # Widget to show the issues
      #
      # This is a CWM wrapper of {Y2Storage::Widgets::Issues}.
      class IssuesWidget < CWM::CustomWidget
        # @see Y2Storage::Widgets::Issues#content
        def contents
          raw_widget.content
        end

        # Event handler
        #
        # @param event [Hash] UI event
        # @return [nil]
        def handle(event)
          raw_widget.handle_event if event["ID"] == raw_widget.id

          nil
        end

        private

        # Widget used to show the list of issues and their details
        #
        # @return [Y2Storage::Widgets::Issues]
        def raw_widget
          @raw_widget ||= Y2Storage::Widgets::Issues.new(id: "issues", issues:)
        end

        # List of probing issues
        #
        # @return [Y2Issues::List]
        def issues
          DeviceGraphs.instance.system.probing_issues
        end
      end
    end
  end
end
