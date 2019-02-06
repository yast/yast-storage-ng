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

require "yast"
require "yast/i18n"
require "yast2/popup"
require "cwm/tree_pager"
require "y2partitioner/dialogs/main"
require "y2storage/inhibitors"
require "y2storage"

module Y2Partitioner
  # YaST "clients" are the CLI entry points
  module Clients
    # The entry point for starting partitioner on its own. Use probed and staging device graphs.
    class Main
      include Yast::I18n
      include Yast::Logger

      def initialize
        textdomain "storage"
      end

      # Runs the client
      #
      # @see #run_partitioner?
      #
      # @param allow_commit [Boolean] whether the changes can be stored on disk
      def run(allow_commit: true)
        return nil if !run_partitioner?

        begin
          inhibitors = Y2Storage::Inhibitors.new
          inhibitors.inhibit

          return nil if partitioner_dialog.nil? || partitioner_dialog.run != :next
          allow_commit ? commit : forbidden_commit_warning
        ensure
          inhibitors.uninhibit
        end
      end

    private

      # Whether to run the Partitioner
      #
      # A warning message is always shown before starting. The partitioner is
      # run only if the user accepts the warning. The storage stack needs to be
      # initialized in read-write access mode.
      #
      # @return [Boolean]
      def run_partitioner?
        start_partitioner_warning == :yes &&
          setup_storage_manager
      end

      # Tries to initialize the storage stack
      #
      # @return [Boolean] true if storage was initialized in rw mode;
      #   false otherwise.
      def setup_storage_manager
        Y2Storage::StorageManager.setup(mode: :rw)
      end

      # @return [Y2Storage::StorageManager]
      def storage_manager
        Y2Storage::StorageManager.instance
      end

      # Saves on disk all changes performed by the user
      def commit
        storage_manager.staging = partitioner_dialog.device_graph
        storage_manager.commit
      end

      # Partitioner dialog is initalized with the probed and staging devicegraphs
      #
      # @return [Dialogs::Main, nil] nil if it was not possible to get the
      #   devicegraphs (probing failed)
      def partitioner_dialog
        return @partitioner_dialog if @partitioner_dialog

        # Force quitting if probing failed
        return nil unless storage_manager.probed

        @partitioner_dialog = Dialogs::Main.new(storage_manager.probed, storage_manager.staging)
      end

      # Popup to alert the user about using the Partitioner
      #
      # @return [Symbol] user's answer (:yes, :no)
      def start_partitioner_warning
        message = _(
          "Only use this program if you are familiar with partitioning hard disks.\n\n" \
          "Never partition disks that may, in any way, be in use\n" \
          "(mounted, swap, etc.) unless you know exactly what you are\n" \
          "doing. Otherwise, the partitioning table will not be forwarded to the\n" \
          "kernel, which will most likely lead to data loss.\n\n" \
          "To continue despite this warning, click Yes."
        )

        Yast2::Popup.show(message, headline: :warning, buttons: :yes_no)
      end

      # Popup when commit is forbidden (e.g., when the client is used for manual testing)
      def forbidden_commit_warning
        # TRANSLATORS: this comment is only for testing purposes. Do not care too much.
        message = _("Nothing gets written because commit is not allowed.")

        Yast2::Popup.show(message)
      end
    end
  end
end
