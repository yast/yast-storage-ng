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

require "erb"
require "yast"
require "y2issues/list"

module Y2Storage
  module Widgets
    # Widget to show storage issues
    #
    # This class implements a composed widget with a table at top and a richtext at the bottom. The
    # issues are listed in the table, and the richtext box shows the details of the currently selected
    # issue.
    #
    # @example:
    #   widget = Issues.new(id: "issues-widget", issues: issues)
    #   widget.content        #=> Yast::Term
    #   widget.handle_event   #=> updates richtext content
    class Issues
      include Yast::UIShortcuts
      include Yast::I18n

      # Widget id
      #
      # @return [String, Symbol]
      attr_reader :id

      # Constructor
      #
      # @param id [String, Symbol] widget id
      # @param issues [Y2Issues::List] list of issues
      def initialize(id:, issues: Y2Issues::List.new)
        textdomain "storage"

        @id = id
        @issues = issues
      end

      # Content of the widget
      #
      # The widget contains a table and a richtext box. The table is used to list the issues and the
      # details of the selected issue are shown in the richtext box.
      #
      # @return [Yast::Term]
      def content
        text = _("Select an issue to see the details.")

        VBox(
          Left(Label(text)),
          VSpacing(0.4),
          MinSize(70, 10, table_widget),
          VSpacing(0.4),
          MinSize(70, 12, details_widget)
        )
      end

      # Updates the richtext with the details of the currently selected issue
      def handle_event
        Yast::UI.ChangeWidget(Id("#{id}-details"), :Value, details(selected_issue))
      end

      private

      # @return [Y2Issues::List]
      attr_reader :issues

      # @return [Yast::Term]
      def table_widget
        Table(
          Id(id),
          Opt(:notify, :immediate),
          Header("#", _("Issue Message")),
          issues_items
        )
      end

      # @return [Yast::Term]
      def details_widget
        VBox(
          Left(Label(_("Details:"))),
          RichText(Id("#{id}-details"), details(issues.first))
        )
      end

      # @return [Array<Yast::Item>]
      def issues_items
        issues.map.with_index { |issue, i| Item(Id("#{id}-#{i}"), i + 1, issue.message) }
      end

      # Currently selected issue
      #
      # @return [Issue]
      def selected_issue
        item_id = Yast::UI.QueryWidget(Id(id), :CurrentItem)
        index = item_id.split("-").last.to_i
        issues.to_a[index]
      end

      # Details of the given issue
      #
      # @param issue [Issue]
      # @return [String]
      def details(issue)
        return _("No details") if !issue&.description && !issue&.details

        details = [issue.description]
        details += [_("Technical details (English only):"), issue.details] if issue.details

        details = details.compact.join("\n\n")

        richtext(details)
      end

      # Converts plain text into richtext
      #
      # @param text [String]
      # @return [String]
      def richtext(text)
        ERB::Util.html_escape(text).gsub("\n", "<br>")
      end
    end
  end
end
