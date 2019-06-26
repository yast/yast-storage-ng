# Copyright (c) [2019] SUSE LLC
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

require "cwm"
require "yast2/popup"
require "y2partitioner/filesystem_errors"

module Y2Partitioner
  module Widgets
    # Widget to set filesystem options
    #
    # Includes logic for some validations.
    class FilesystemOptions < CWM::CustomWidget
      include FilesystemErrors

      # Constructor
      #
      # @param controller [Y2Partitioner::Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller

        self.handle_all_events = true
      end

      # @macro seeAbstractWidget
      # Whether the indicated values are valid
      #
      # @note A warning popup is shown if there are some warnings.
      #
      # @see #warnings
      #
      # @return [Boolean] true if the user decides to continue despite of the
      #   warnings; false otherwise.
      def validate
        current_warnings = warnings
        return true if current_warnings.empty?

        message = current_warnings
        message << _("Do you want to continue with the current setup?")
        message = message.join("\n\n")

        Yast2::Popup.show(message, headline: :warning, buttons: :yes_no) == :yes
      end

      private

      # @return [Y2Partitioner::Actions::Controllers::Filesystem]
      attr_reader :controller

      # Warnings detected in the given values. For now, it only contains
      # warnings for the selected filesystem.
      #
      # @see FilesysteValidation
      #
      # @return [Array<String>]
      def warnings
        filesystem_errors(controller.filesystem)
      end
    end
  end
end
