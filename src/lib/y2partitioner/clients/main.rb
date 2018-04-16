# encoding: utf-8

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

require "cwm/tree_pager"
require "y2partitioner/device_graphs"
require "y2partitioner/dialogs/main"
require "y2storage"

Yast.import "Popup"

module Y2Partitioner
  # YaST "clients" are the CLI entry points
  module Clients
    # The entry point for starting partitioner on its own. Use probed and staging device graphs.
    class Main
      extend Yast::I18n

      def initialize
        textdomain "storage"
      end

      # Run the client
      #
      # It tries to initialize the storage object with read-write access mode.
      #
      # @see Y2Storage::StorageManager.setup
      #
      # @param allow_commit [Boolean] can we pass the point of no return
      def self.run(allow_commit: true)
        return nil unless Y2Storage::StorageManager.setup(mode: :rw)

        smanager = Y2Storage::StorageManager.instance
        dialog = Dialogs::Main.new
        res = dialog.run(smanager.probed, smanager.staging)

        # Running system: presenting "Expert Partitioner: Summary" step now
        # ep-main.rb SummaryDialog
        if res == :next && should_commit?(allow_commit)
          smanager.staging = dialog.device_graph
          smanager.commit
        end
      end

      # Ask whether to proceed with changing the disks; or inform that we will not do it.
      #
      # @return [Boolean] proceed
      def self.should_commit?(allow_commit)
        if allow_commit
          q = _("Modify the disks and potentially destroy your data?")
          Yast::Popup.ContinueCancel(q)
        else
          m = _("Nothing gets written, because the device graph is fake.")
          Yast::Popup.Message(m)
          false
        end
      end
    end
  end
end
