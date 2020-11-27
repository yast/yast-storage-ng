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

require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/tmpfs_options"

module Y2Partitioner
  module Dialogs
    # Dialog to create and edit a tmpfs filesystem
    class Tmpfs < Base
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        super()

        textdomain "storage"

        @controller = controller
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(widget)
      end

      private

      # @return [Actions::Controllers::Filesystem]
      attr_reader :controller

      # Widget for Tmpfs options
      #
      # @return [Widgets::TmpfsOptions]
      def widget
        @widget ||= Widgets::TmpfsOptions.new(controller)
      end
    end
  end
end
