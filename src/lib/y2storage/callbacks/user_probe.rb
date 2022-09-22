# Copyright (c) [2018-2021] SUSE LLC
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
require "y2storage/issues_reporter"

module Y2Storage
  module Callbacks
    # Class to implement callbacks used during probing
    class UserProbe
      include Yast::I18n
      include Yast::Logger

      def initialize
        textdomain "storage"
      end

      # Reports probing issues
      #
      # @todo Replace the issues manager with just a list of issues
      #
      # @param IssuesList [IssuesList] Probing issues
      # @return [Boolean] true if the user acknowledges the issues and wants
      #   to continue; false otherwise.
      def report_probing_issues(issues)
        return true if issues.empty?

        reporter = Y2Storage::IssuesReporter.new(issues)
        reporter.report(message: _("Issues found while analyzing the storage devices."))
      end
    end
  end
end
