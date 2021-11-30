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
require "y2issues/list"
require "y2storage/issues_reporter"
require "y2storage/storage_env"

module Y2Storage
  # Class to manage issues associated to a devicegraph
  class IssuesManager
    include Yast::I18n

    # List of probing issues
    #
    # @return [Y2Issues::List]
    attr_accessor :probing_issues

    # Constructor
    #
    # @param devicegraph [Devicegraph]
    def initialize(devicegraph)
      textdomain "storage"

      @devicegraph = devicegraph
      @probing_issues = Y2Issues::List.new
    end

    # Reports probing issues
    #
    # If there are probing issues, then the user is asked whether to continue.
    # If the $LIBSTORAGE_IGNORE_PROBE_ERRORS environment variable is set, the issues are not reported to
    # the user.
    #
    # @return [Boolean]
    def report_probing_issues
      return true if probing_issues.empty? || StorageEnv.instance.ignore_probe_errors?

      reporter = IssuesReporter.new(probing_issues)

      reporter.report(message: probing_issues_message)
    end

    private

    # @return [Devicegraph]
    attr_reader :devicegraph

    # Message to include when reporting probing issues
    #
    # @return [String]
    def probing_issues_message
      _("The following errors were found while analyzing the storage devices.")
    end
  end
end
