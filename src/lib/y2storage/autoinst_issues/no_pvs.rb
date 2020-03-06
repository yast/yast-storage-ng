# Copyright (c) [2020] SUSE LLC
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
require "y2storage/autoinst_issues/issue"

module Y2Storage
  module AutoinstIssues
    # No suitable physical volumes were found for this volume group
    class NoPvs < Issue
      attr_reader :planned_vg

      # @param planned_vg [Planned::LvmVg] Planned volume group
      def initialize(planned_vg)
        textdomain "storage"

        @planned_vg = planned_vg
      end

      # Fatal problem
      #
      # @return [Symbol] :warn
      # @see Issue#severity
      def severity
        :fatal
      end

      # Return the error message to be displayed
      #
      # @return [String] Error message
      # @see Issue#message
      def message
        format(
          _("Could not find a suitable physical volume for\nvolume group '%{vg_name}'."),
          vg_name: planned_vg.volume_group_name
        )
      end
    end
  end
end
