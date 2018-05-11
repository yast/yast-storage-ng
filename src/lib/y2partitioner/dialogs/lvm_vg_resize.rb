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
require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/lvm_vg_devices_selector"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Form to set the devices of a volume group
    class LvmVgResize < Base
      # Constructor
      #
      # @param controller [Actions::Controllers::LvmVg]
      def initialize(controller)
        textdomain "storage"
        @controller = controller
      end

      # @macro seeDialog
      def title
        controller.wizard_title
      end

      # @macro seeDialog
      def contents
        VBox(
          Widgets::LvmVgDevicesSelector.new(controller)
        )
      end

    private

      # @return [Actions::Controllers::LvmVg]
      attr_reader :controller
    end
  end
end
