# Copyright (c) [2020] SUSE LLC
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
require "y2partitioner/widgets/format_and_mount"

module Y2Partitioner
  module Widgets
    # Widget to set tmpfs options
    class TmpfsOptions < MountOptions
      # Constructor
      #
      # @param controller [Actions::Controllers::Filesystem]
      # @param edit [Boolean] whether the tmpfs is being edited. False if the widget
      #   is being used to create a new tmpfs object
      def initialize(controller, edit)
        textdomain "storage"

        @edit = edit
        super(controller, nil)
      end

      # @macro seeAbstractWidget
      def contents
        VBox(
          Left(@mount_point_widget),
          VSpacing(0.5),
          Left(@fstab_options_widget)
        )
      end

      # @see MountOptions
      def refresh
        @mount_point_widget.refresh
        @mount_point_widget.disable if @edit
        mount_point_change
      end

      # @macro seeAbstractWidget
      def handle(event)
        mount_point_change if event["ID"] == @mount_point_widget.widget_id

        nil
      end

      def help
        _(
          "<p>The tmpfs facility allows the creation of very fast file systems whose contents " \
          "reside in virtual memory. The file system is automatically created in the moment of " \
          "mounting it and the contents are lost when the file system is unmounted.</p>" \
          "<p>Although the file system consumes only as much memory as required by its current " \
          "contents, its max size is limited automatically by the system based on the total " \
          "amount of RAM. That max limit can be customized with the appropriate fstab option.</p>"
        )
      end

      def validate
        return false unless super
        return true unless controller.mount_point&.root?

        Yast::Popup.Error(
          _("Installing into a temporary file system is not supported.")
        )
        @mount_point_widget.focus
        false
      end
    end
  end
end
