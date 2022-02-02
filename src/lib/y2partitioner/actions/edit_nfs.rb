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
require "y2partitioner/actions/base"
require "y2partitioner/dialogs/nfs"

module Y2Partitioner
  module Actions
    # Action for modifying an existing NFS mount
    class EditNfs < Base
      include Yast::Logger

      # Constructor
      #
      # @param nfs [Y2Storage::Nfs] device to modify
      def initialize(nfs)
        super()

        @nfs = nfs
        @legacy_nfs = Y2Storage::Filesystems::LegacyNfs.new_from_nfs(nfs)
        @nfs_entries = (nfs.devicegraph.nfs_mounts - [nfs]).map do |mount|
          Y2Storage::Filesystems::LegacyNfs.new_from_nfs(mount)
        end
      end

      private

      # @return [Y2Storage::Nfs] device to modify
      attr_reader :nfs

      # Representation of {#nfs} in the format used to communicate with yast2-nfs-client
      #
      # @return [Y2Storage::Filesystems::LegacyNfs]
      attr_reader :legacy_nfs

      # Entries used by the NfsForm to check for duplicate mount points
      #
      # @return [Array<Y2Storage::Filesystems::LegacyNfs>]
      attr_reader :nfs_entries

      # Only runs the action if yast2-nfs-client is installed, see {Dialogs::Nfs}.
      #
      # @see Base#run?
      def run?
        super && Dialogs::Nfs.run?
      end

      # Only step of the wizard
      #
      # @see Dialogs::Nfs
      #
      # @return [Symbol] :finish when the dialog successes
      def perform_action
        dialog = Dialogs::Nfs.new(legacy_nfs, nfs_entries)
        return unless dialog.run?

        result = dialog.run
        return unless result == :next

        @nfs = legacy_nfs.update_or_replace(nfs)
        UIState.instance.select_row(nfs.sid)

        :finish
      end
    end
  end
end
