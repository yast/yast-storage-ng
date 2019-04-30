# encoding: utf-8

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

require "y2partitioner/widgets/filesystem_options"
require "y2partitioner/widgets/format_and_mount"

module Y2Partitioner
  module Widgets
    # Widget to set Btrfs options like mount point, subvolumes, snapshots, etc.
    class BtrfsOptions < FilesystemOptions
      # @macro seeAbstractWidget
      def contents
        VBox(
          mount_options_widget,
          VSpacing(0.5),
          snapshots_widget
        )
      end

      # @macro seeAbstractWidget
      def init
        refresh_snapshots_widget
      end

      # Used by the children widgets to notify they have changed the status of
      # the controller and, thus, some of its sibling widgets may need a refresh.
      #
      # @param exclude [CWM::AbstractWidget] widget producing the change, and thus
      #   not needing a forced refresh
      def refresh_others(exclude)
        return unless exclude == mount_options_widget

        refresh_snapshots_widget
      end

    private

      # Widget to set mount options
      #
      # @return [Widgets::MountOptions]
      def mount_options_widget
        @mount_options_widget ||= Widgets::MountOptions.new(controller, self)
      end

      # Widget to set snapshots
      #
      # @return [Widgets::Snapshots]
      def snapshots_widget
        @snapshots_widget ||= Widgets::Snapshots.new(controller)
      end

      # Refreshes the snapshots widget
      #
      # The widget is enabled/disabled according to the user selections regarding
      # the mount point.
      def refresh_snapshots_widget
        if controller.snapshots_supported?
          snapshots_widget.enable
        else
          controller.configure_snapper = false
          snapshots_widget.disable
        end

        snapshots_widget.refresh
      end
    end
  end
end
