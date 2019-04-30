# encoding: utf-8

# Copyright (c) [2017-2019] SUSE LLC
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
require "y2partitioner/widgets/filesystem_options"
require "y2partitioner/widgets/format_and_mount"

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
      class FormatMountOptions < Widgets::FilesystemOptions
        # Constructor
        #
        # @param controller [Y2Partitioner::Actions::Controllers::Filesystem]
        def initialize(controller)
          textdomain "storage"

          super

          @format_options = Widgets::FormatOptions.new(controller, self)
          @mount_options = Widgets::MountOptions.new(controller, self)
        end

        # @macro seeAbstractWidget
        def contents
          HBox(
            Frame(
              _("Formatting Options"),
              MarginBox(1.45, 0.5, @format_options)
            ),
            HSpacing(5),
            Frame(
              _("Mounting Options"),
              MarginBox(1.45, 0.5, @mount_options)
            )
          )
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
      end
    end
  end
end
