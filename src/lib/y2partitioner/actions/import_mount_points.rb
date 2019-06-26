# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/actions/base"
require "y2partitioner/actions/controllers/fstabs"
require "y2partitioner/dialogs/import_mount_points"

module Y2Partitioner
  module Actions
    # Action for importing mount points from a fstab file
    class ImportMountPoints < Base
      include Yast::I18n

      # Constructor
      def initialize
        super

        textdomain "storage"

        @controller = Controllers::Fstabs.new
      end

      private

      # @return [Controllers::Fstab]
      attr_reader :controller

      # Opens a dialog to import mount points
      #
      # The mount points are imported only if the dialog is accepted.
      #
      # @see Actions::Base#perform_action
      #
      # @return [Symbol] result of the dialog
      def perform_action
        dialog_result = import_dialog.run

        controller.import_mount_points if dialog_result == :ok

        dialog_result
      end

      # Dialog to import mount points from a fstab file
      #
      # @return [Dialogs::ImportMountPoints]
      def import_dialog
        @import_dialog ||= Dialogs::ImportMountPoints.new(controller)
      end

      # Result of the action
      #
      # @see Actions::Base#result
      #
      # It returns `:finish` when the action is performed. Otherwise, it returns
      # the result of the dialog, see {#perform_action}.
      #
      # @param action_result [Symbol] result of {#permorm_action}
      # @return [Symbol]
      def result(action_result)
        return super if action_result == :ok

        action_result
      end

      # List of errors that avoid to import mount points
      #
      # @see Actions::Base#errors
      #
      # @return [Array<String>]
      def errors
        (super + [no_fstab_error]).compact
      end

      # Error message when no fstab file was detected
      #
      # @return [String, nil] nil if there is some fstab
      def no_fstab_error
        return nil if controller.fstabs.any?

        _("YaST has scanned your hard disks but no fstab file was found.")
      end
    end
  end
end
