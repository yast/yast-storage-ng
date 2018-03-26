# encoding: utf-8

# Copyright (c) 2018 SUSE LLC
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

Yast.import "Report"
Yast.import "Popup"
Yast.import "Label"
Yast.import "Mode"

module Y2Storage
  module Callbacks
    # Class to implement callbacks used when the probed devicegraph needs to
    # be sanitized
    class Sanitize
      include Yast::Logger
      include Yast::I18n

      def initialize
        textdomain "storage"
      end

      # Callback to report probed devicegraph errors to the user.
      #
      # It offers the user the possibility to sanitize the devicegraph.
      #
      # @param errors [Array<String>] Errors detected in probed devicegraph.
      # @return [Boolean] true if the user decides to sanitize the devicegraph.
      def sanitize?(errors)
        log.info "probed devicegraph contains errors, asking the user whether to sanitize it"
        log.info "Errors details: #{errors}"

        header = _("The following errors were detected in the system:")
        error_messages = errors.join("\n\n")
        confirm = _("Do you want to continue?")

        message = "#{header}\n\n#{error_messages}\n\n#{confirm}"

        result = Yast::Report.ErrorAnyQuestion(
          Yast::Popup.NoHeadline,
          message,
          Yast::Label.ContinueButton,
          abort_button_label,
          :focus_yes
        )

        log.info "User answer: #{result}"

        result
      end

      # Label for the abort button displayed by {#sanitize?}
      #
      # @return [String]
      def abort_button_label
        Yast::Mode.installation ? Yast::Label.AbortInstallationButton : Yast::Label.AbortButton
      end
    end
  end
end
