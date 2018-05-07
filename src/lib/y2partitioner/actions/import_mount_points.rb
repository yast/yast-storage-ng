# encoding: utf-8

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
require "y2partitioner/actions/controllers/fstabs"
require "y2partitioner/dialogs/import_mount_points"

module Y2Partitioner
  module Actions
    # Action for importing mount points from a fstab file
    class ImportMountPoints
      include Yast::I18n

      # Constructor
      def initialize
        textdomain "storage"

        @controller = Controllers::Fstabs.new
      end

      # Shows the dialog for importing mount points and performs the action
      # if user selects to import
      #
      # @return [Symbol]
      def run
        return :back unless validate

        dialog_result = import_dialog.run
        return dialog_result unless dialog_result == :ok

        controller.import_mount_points
        :finish
      end

    private

      # @return [Controllers::Fstab]
      attr_reader :controller

      # Dialog to import mount points from a fstab file
      #
      # @return [Dialogs::ImportMountPoints]
      def import_dialog
        @import_dialog ||= Dialogs::ImportMountPoints.new(controller)
      end

      # Checks whether the import dialog can be shown
      #
      # The dialog is shown if it was possible to read some fstab file.
      #
      # @return [Boolean]
      def validate
        error = no_fstab_error
        return true if error.nil?

        Yast2::Popup.show(error, headline: :error)

        false
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
