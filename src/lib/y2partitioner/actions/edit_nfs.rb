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
require "y2nfs_client/widgets/nfs_form"

module Y2Partitioner
  module Actions
    # Action for creating a new NFS mount
    class EditNfs < Base
      include Yast::Logger

      # Constructor
      def initialize(nfs)
        super()
        textdomain "storage"

        @nfs = nfs
        @initial_legacy_nfs = Y2Storage::Filesystems::LegacyNfs.new_from_nfs(nfs)
        @nfs_entries = (nfs.devicegraph.nfs_mounts - [nfs]).map do |mount|
          Y2Storage::Filesystems::LegacyNfs.new_from_nfs(mount)
        end
      end

      private

      attr_reader :initial_legacy_nfs
      attr_reader :nfs_entries
      attr_reader :nfs

      # Only step of the wizard
      #
      # @see Dialogs::Nfs
      #
      # @return [Symbol] :finish when the dialog successes
      def perform_action
        result = Dialogs::Nfs.run(form, title)
        return unless result == :next

        @nfs = form.nfs.update_or_replace(nfs)
        UIState.instance.select_row(nfs.sid)

        :finish
      end

      def form
        @form ||= Y2NfsClient::Widgets::NfsForm.new(initial_legacy_nfs, nfs_entries)
      end

      # Wizard title
      #
      # @return [String]
      def title
        # TRANSLATORS: wizard title
        _("Edit NFS mount")
      end
    end
  end
end
