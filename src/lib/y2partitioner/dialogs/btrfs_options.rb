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

require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/btrfs_options"

module Y2Partitioner
  module Dialogs
    # Dialog to set Btrfs options like mount point, subvolumes, snapshots, etc.
    class BtrfsOptions < Base
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
        HVSquash(btrfs_options_widget)
      end

    private

      # @return [Actions::Controllers::Filesystem]
      attr_reader :controller

      # Widget for Btrfs options
      #
      # @return [Widgets::BtrfsOptions]
      def btrfs_options_widget
        @btrfs_options_widget ||= Widgets::BtrfsOptions.new(controller)
      end
    end
  end
end
