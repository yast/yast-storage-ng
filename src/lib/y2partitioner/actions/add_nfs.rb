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
require "y2nfs_client/actions"

module Y2Partitioner
  module Actions
    # Action for creating a new NFS mount
    class AddNfs < Base
      include Yast::Logger

      # Constructor
      def initialize
        super
        textdomain "storage"
      end

      private

      attr_reader :nfs_action

      # Only step of the wizard
      #
      # @see Dialogs::Nfs
      #
      # @return [Symbol] :finish when the dialog successes
      def perform_action
        result = Dialogs::Nfs.run(form, title)
        return unless result == :next

        nfs_action = Y2NfsClient::Actions::AddNfs.new(form.nfs, devicegraph)
        nfs = nfs_action.create_reachable_device { |confirm_msg| Yast::Popup.YesNo(confirm_msg) }
        UIState.instance.select_row(nfs.sid) if nfs

        :finish
      end

      def form
        @form ||= Y2NfsClient::Widgets::NfsForm.new(devicegraph)
      end

      # Wizard title
      #
      # @return [String]
      def title
        # TRANSLATORS: wizard title
        _("Add NFS mount")
      end

      def devicegraph
        DeviceGraphs.instance.current
      end
    end
  end
end
