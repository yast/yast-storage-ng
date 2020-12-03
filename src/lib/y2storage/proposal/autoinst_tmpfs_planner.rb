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

require "y2storage/proposal/autoinst_drive_planner"
require "y2storage/planned/tmpfs"

module Y2Storage
  module Proposal
    # This class converts an AutoYaST specification into a Planned::Tmpfs
    class AutoinstTmpfsPlanner < AutoinstDrivePlanner
      # Returns a planned Tmpfs according to an AutoYaST specification
      #
      # @param drive_section [AutoinstProfile::DriveSection] drive section describing the Tmpfs
      # @return [Array<Planned::Tmpfs>] Array containing the planned Tmpfs
      def planned_devices(drive_section)
        drive_section.partitions.map { |p| planned_tmpfs(p) }
      end

      private

      # Generates a planned Tmpfs from a drive section
      #
      # @return [Planned::Tmpfs]
      def planned_tmpfs(partition_section)
        Planned::Tmpfs.new(partiton_section.mount, partition_section.fstab_options)
      end
    end
  end
end
