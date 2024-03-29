# Copyright (c) [2019] SUSE LLC
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

module Y2Storage
  module AutoinstIssues
    # The proposal contains a drive section which is not supported in the current architecture
    #
    # This is a fatal error.
    class UnsupportedDriveSection < ::Installation::AutoinstIssues::Issue
      def initialize(section)
        super()

        textdomain "storage"

        @section = section
      end

      # Return problem severity
      #
      # @return [Symbol] :fatal
      def severity
        :fatal
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @see Issue#message
      def message
        # TRANSLATORS: 'type' is the type of the AutoYaST drive section
        format(_("A drive of type '%{type}' is not supported in this architecture"), type: section.type)
      end
    end
  end
end
