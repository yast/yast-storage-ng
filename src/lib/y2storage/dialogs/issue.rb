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

require "yast"
require "yast2/popup"
require "ui/text_helpers"

module Y2Storage
  module Dialogs
    # Popup to show a storage issue
    class Issue
      include Yast::I18n

      include UI::TextHelpers

      # Shows the dialog
      #
      # A Yast2::Popup is internally used, but only some parameters from Yast2::Popup.show make sense
      # for this dialog.
      #
      # @see Issue#show
      def self.show(*args)
        new(*args).show
      end

      # Constructor
      #
      # See Yast2::Popup for the meaning of the parameters.
      #
      # @param issue [Y2Storage::Issue]
      # @param footer [String] this text will be added at the end
      # rubocop:disable Metrics/ParameterLists
      def initialize(issue,
        headline: "", timeout: 0, focus: nil, buttons: :ok, style: :notice, footer: nil)

        textdomain "storage"

        @issue = issue
        @headline = headline
        @timeout = timeout
        @focus = focus
        @buttons = buttons
        @style = style
        @footer = footer
      end
      # rubocop:enable Metrics/ParameterLists

      # Uses a Yast2::Popup to show the issue
      #
      # @return [Symbol] see Yast2::Popup
      def show
        # note: the headline is ommited in order to keep the previous behavior when an error was reported
        # with the Yast::Report module.
        Yast2::Popup.show(full_message,
          headline: "", timeout: timeout, focus: focus, buttons: buttons, style: style, details: details)
      end

      private

      # Issue to show
      #
      # @return [Y2Issues::List]
      attr_reader :issue

      # @see Yast2::Popup
      attr_reader :headline

      # @see Yast2::Popup
      attr_reader :timeout

      # @see Yast2::Popup
      attr_reader :focus

      # @see Yast2::Popup
      attr_reader :buttons

      # @see Yast2::Popup
      attr_reader :style

      # Footer text
      #
      # @return [String, nil]
      attr_reader :footer

      # Message to show, which includes the issue message, description, footer, etc.
      #
      # @return [String]
      def full_message
        if issue.details
          "#{issue.message}\n\n#{description}\n\n#{hint}\n\n#{footer}"
        else
          "#{issue.message}\n\n#{description}\n\n#{footer}"
        end
      end

      # @return [String]
      def description
        issue&.description || _("Unexpected situation found in the system.")
      end

      # @return [String]
      def details
        wrap_text(issue&.details || "")
      end

      # @return [String]
      def hint
        _("Click below to see more details (English only).")
      end
    end
  end
end
