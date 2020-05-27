# Copyright (c) [2017] SUSE LLC
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

require "installation/autoinst_issues/issue"

module Installation
  module AutoinstIssues
    # Represents a situation where a suitable device to be reused was not found.
    #
    # @example
    #   section = AutoinstProfile::PartitionSection.new_from_hashes({})
    #   problem = MissingReusableDevice.new(section)
    class MissingReusableDevice < ::Installation::AutoinstIssues::Issue
      # @param section [#parent,#section_name] Section where it was detected
      #                (see {Y2Storage::AutoinstProfile})
      def initialize(section)
        textdomain "storage"

        @section = section
      end

      # Return problem severity
      #
      # @return [Symbol] :warn
      # @see Issue#severity
      def severity
        :warn
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @see Issue#message
      def message
        _("Reusable device not found")
      end
    end
  end
end
