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
      def initialize(controller)
        textdomain "storage"

        super(controller, nil)
      end

      # @macro seeAbstractWidget
      def contents
        VBox(
          Left(@mount_point_widget),
          VSpacing(0.5),
          Left(@fstab_options_widget),
        )
      end

      # @see MountOptions
      def refresh
        mount_point_change
      end

      # @macro seeAbstractWidget
      def handle(event)
        if event["ID"] == @mount_point_widget.widget_id
          mount_point_change
        end

        nil
      end
    end
  end
end
