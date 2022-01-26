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
    class AddNfs < Base
      include Yast::Logger
      Yast.import "Popup"

      # Constructor
      def initialize
        super
        textdomain "storage"
      end

      private

      # Only step of the wizard
      #
      # @see Dialogs::Nfs
      #
      # @return [Symbol] :finish when the dialog successes
      def perform_action
        result = Dialogs::Nfs.run(form, title)
        return unless result == :next

        nfs = create_reachable_device(form.nfs)
        UIState.instance.select_row(nfs.sid) if nfs

        :finish
      end

      def form
        @form ||= Y2NfsClient::Widgets::NfsForm.new(Y2Storage::Filesystems::LegacyNfs.new, nfs_entries)
      end

      def nfs_entries
        devicegraph.nfs_mounts.map { |i| Y2Storage::Filesystems::LegacyNfs.new_from_nfs(i) }
      end

      # Wizard title
      #
      # @return [String]
      def title
        # TRANSLATORS: wizard title
        _("Add NFS mount")
      end

      def create_reachable_device(legacy)
        nfs = legacy.create_nfs_device(devicegraph)
        return nfs if nfs.reachable?

        # Rollback only if user does not want to save (bsc#450060)
        keep = save_unreachable_nfs?(nfs)
        log.warn "Test mount of NFS share #{nfs.inspect} failed. Save anyway?: #{keep}"
        return nfs if keep

        devicegraph.remove_nfs(nfs)
        nil
      end

      def save_unreachable_nfs?(nfs)
        # TRANSLATORS: pop-up message. %s is replaced for something like 'server:/path'
        msg = _("Test mount of NFS share '%s' failed.\nSave it anyway?") % nfs.name
        Yast::Popup.YesNo(msg)
      end

      def devicegraph
        DeviceGraphs.instance.current
      end
    end
  end
end
