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
require "cwm/widget"
require "y2partitioner/actions/import_mount_points"

module Y2Partitioner
  module Widgets
    # Button for importing mount points from a fstab file
    class ImportMountPointsButton < CWM::PushButton
      def initialize
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        _("Import Mount Points...")
      end

      # @return [Symbol, nil] nil when the action was not performed
      def handle
        action_result = Actions::ImportMountPoints.new.run
        action_result == :finish ? :redraw : nil
      end
    end
  end
end
