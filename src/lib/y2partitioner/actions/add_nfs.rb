# Copyright (c) [2022] SUSE LLC
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
require "y2partitioner/ui_state"
require "y2partitioner/dialogs/nfs"

module Y2Partitioner
  module Actions
    # Action for creating a new NFS mount
    class AddNfs < Base
      include Yast::Logger

      # Constructor
      def initialize
        super

        @legacy_nfs = Y2Storage::Filesystems::LegacyNfs.new
        @legacy_nfs.fstopt = "defaults"
      end

      private

      # Template for the new NFS object to be created
      #
      # @return [Y2Storage::Filesystems::LegacyNfs]
      attr_reader :legacy_nfs

      # Only step of the wizard
      #
      # @see Dialogs::Nfs
      #
      # @return [Symbol] :finish when the dialog successes
      def perform_action
        result = Dialogs::Nfs.run(legacy_nfs, nfs_entries)
        return unless result == :next

        nfs = legacy_nfs.create_nfs_device(devicegraph)
        UIState.instance.select_row(nfs.sid)

        :finish
      end

      # Entries used by the NfsForm to check for duplicate mount points
      #
      # @return [Array<Y2Storage::Filesystems::LegacyNfs>]
      def nfs_entries
        devicegraph.nfs_mounts.map { |i| Y2Storage::Filesystems::LegacyNfs.new_from_nfs(i) }
      end

      # Devicegraph to create the new NFS object
      #
      # @return [Y2Storage::Devicegraph]
      def devicegraph
        DeviceGraphs.instance.current
      end
    end
  end
end
