# Copyright (c) [2017-2020] SUSE LLC
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
require "y2partitioner/actions/rescan_devices"
require "y2partitioner/execute_and_redraw"

Yast.import "Popup"
Yast.import "Mode"

module Y2Partitioner
  module Widgets
    # Button for rescanning system devices
    class RescanDevicesButton < CWM::PushButton
      include ExecuteAndRedraw

      def initialize
        textdomain "storage"
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to rescan devices
        _("Rescan Devices")
      end

      # Shows a confirm message before reprobing
      #
      # @return [Symbol, nil]
      def handle
        execute_and_redraw { Actions::RescanDevices.new.run }
      end

      # @macro seeAbstractWidget
      def help
        # TRANSLATORS: help text for the Partitioner
        _(
          "<p>The <b>Rescan Devices</b> button refreshes the information about storage " \
          "devices.</p>"
        )
      end
    end
  end
end
