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

require "yast2/popup"
require "y2storage/widgets/issues"

module Y2Storage
  module Dialogs
    # Popup to show storage issues
    #
    # TODO: The class Yast2::Popup only shows text. But sometimes it is needed to show other kind of
    #   content, like tables, checboxes, etc. Ideally, Yast2::Popup should allow to render arbitrary
    #   content. For example, it could receive a presenter and extract the content from it:
    #
    #   presenter = StorageIssuesPresenter.new(issues)
    #   Yast2::Popup.show_content(presenter, buttons: :yes_no, timeout: 10)
    #
    #   With that approach, this Y2Storage::Dialogs::Issues class would not be needed. Moreover, the
    #   Y2Issues::Reporter class would be easily reused by passing a presenter object:
    #
    #   reporter = Y2Issues::Reporter.new(presenter)
    #   reporter.report(warn: :continue)
    class Issues < Yast2::Popup
      class << self
        # List of issues to show
        #
        # @return [Y2Issues::List]
        attr_reader :issues

        # Footer text
        #
        # @return [String, nil]
        attr_reader :footer

        # Shows the dialog
        #
        # Only accepts parameters from Yast2::Popup.show that make sense for this dialog.
        #
        # @param issues [Y2Issues::List]
        # @param message [String] this will be shown before the table of issues
        # @param footer [String] this will be shown after the table of issues
        # rubocop:disable Metrics/ParameterLists
        def show(issues,
          headline: "", timeout: 0, focus: nil, buttons: :ok, style: :notice, message: nil, footer: nil)
          @issues = issues
          @footer = footer

          message ||= ""

          super(message,
            headline: headline, timeout: timeout, focus: focus, buttons: buttons, style: style)
        end
        # rubocop:enable Metrics/ParameterLists

        # @see Yast2::Popup
        def message_widget(message, *_args)
          VBox(
            intro_widget(message),
            issues_widget.content,
            footer_widget
          )
        end

        # Widget to show the given message
        #
        # @return [Yast::Term]
        def intro_widget(message)
          return Empty() if message.to_s.empty?

          VBox(
            Left(Label(message)),
            VSpacing(0.4)
          )
        end

        # Widget to show the footer
        #
        # @return [Yast::Term]
        def footer_widget
          return Empty() if footer.to_s.empty?

          VBox(
            VSpacing(0.4),
            Left(Label(footer))
          )
        end

        # Widget to show the issues and their details
        #
        # @return [Widgets::Issues]
        def issues_widget
          @issues_widget ||= Widgets::Issues.new(id: "issues", issues: issues)
        end

        # Delegates the event handling to the widget, when needed
        #
        # @see Yast2::Popup
        def handle_event(*_args)
          result = super
          return result unless result == issues_widget.id

          issues_widget.handle_event
          nil
        end
      end
    end
  end
end
