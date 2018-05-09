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
require "yast2/popup"
require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/format_and_mount"
require "y2partitioner/filesystem_errors"

module Y2Partitioner
  module Dialogs
    # Which filesystem (and options) to use and where to mount it (with options).
    # Part of {Actions::AddPartition} and {Actions::EditBlkDevice}.
    # Formerly MiniWorkflowStepFormatMount
    class FormatAndMount < Base
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
        @format_and_mount = FormatMountOptions.new(controller)
      end

      def title
        @controller.wizard_title
      end

      def contents
        HVSquash(@format_and_mount)
      end

      # Simple container widget to allow the format options and the mount
      # options widgets to refresh each other.
      class FormatMountOptions < CWM::CustomWidget
        include FilesystemErrors

        # Constructor
        #
        # @param controller [Y2Partitioner::Actions::Controllers::Filesystem]
        def initialize(controller)
          textdomain "storage"

          @controller = controller
          @format_options = Widgets::FormatOptions.new(controller, self)
          @mount_options = Widgets::MountOptions.new(controller, self)

          self.handle_all_events = true
        end

        # @macro seeAbstractWidget
        def contents
          HBox(
            @format_options,
            HSpacing(5),
            @mount_options
          )
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

        # Used by the children widgets to notify they have changed the status of
        # the controller and, thus, some of its sibling widgets may need a
        # refresh.
        #
        # @param exclude [CWM::AbstractWidget] widget originating the change,
        #   and thus not needing a forced refresh
        def refresh_others(exclude)
          if exclude == @format_options
            @mount_options.refresh
          else
            @format_options.refresh
          end
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
end
