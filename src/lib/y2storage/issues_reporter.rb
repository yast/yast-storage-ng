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
require "y2issues/reporter"
require "y2storage/dialogs/issue"
require "y2storage/dialogs/issues"

Yast.import "Label"
Yast.import "Mode"

module Y2Storage
  # Reporter for storage issues
  #
  # @TODO: use Y2Issues::Reporter directly, see explanation at Dialogs::Issues.
  class IssuesReporter < Y2Issues::Reporter
    include Yast::I18n

    # @see Y2Issues::Reporter
    def initialize(*args)
      textdomain "storage"

      super

      @issues = args.first
    end

    # @see Y2Issues::Reporter
    def report(warn: :ask, error: :abort, message: nil, focus: nil)
      @message = message
      @focus = focus

      super(warn: warn, error: error)
    end

    private

    # List of issues to report
    #
    # @return [Y2Issues::List]
    attr_reader :issues

    # Message to include when reporting issues
    #
    # @return [String, nil]
    attr_reader :message

    # Button to focus
    #
    # @return [Symbol, nil]
    attr_reader :focus

    # Overloads {Y2Issues::Reporter} in order to use other footer and buttons
    #
    # @see Y2Issues::Reporter
    def show_issues_ask
      footer = n_("Continue despite the error?", "Continue despite the errors?", issues.size)
      buttons = { yes: Yast::Label.ContinueButton, no: abort_button_label }

      popup(footer, buttons) == :yes
    end

    # Overloads {Y2Issues::Reporter} in order to render a custom content instead of richtext.
    #
    # @see Y2Issues::Reporter
    def popup(footer, btns, with_timeout: true)
      time = with_timeout ? @timeout : 0

      show_dialog(footer, btns, time)
    end

    # Label for the abort button
    #
    # @return [String]
    def abort_button_label
      Yast::Mode.installation ? Yast::Label.AbortInstallationButton : Yast::Label.AbortButton
    end

    # Shows a dialog
    #
    # For a single issue, a simpler dialog is used.
    #
    # @see #popup
    def show_dialog(footer, btns, time)
      opts = { headline: header, buttons: btns, focus: focus, timeout: time, footer: footer }

      if issues.size == 1
        Dialogs::Issue.show(issues.first, opts)
      else
        Dialogs::Issues.show(issues, opts.merge(message: message))
      end
    end
  end
end
