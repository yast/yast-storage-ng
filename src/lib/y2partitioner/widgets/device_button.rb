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
require "cwm"
require "y2partitioner/widgets/execute_and_redraw"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Base class for a button that performs some action over a specificic device,
    # e.g., edit, resize, delete, etc.
    class DeviceButton < CWM::PushButton
      include ExecuteAndRedraw

      # Constructor
      # @param pager [CWM::TreePager]
      # @param device [Y2Storage::Device]
      def initialize(pager: nil, device: nil)
        textdomain "storage"

        @pager = pager
        @device_sid = device.sid unless device.nil?
      end

      # @macro seeAbstractWidget
      def handle
        return nil unless validate_presence

        execute_and_redraw { actions }
      end

    protected

      # @return [CWM::TreePager]
      attr_reader :pager

      # @return [Integer] device sid
      attr_reader :device_sid

      # Current devicegraph
      #
      # @return [Y2Storage::Devicegraph]
      def working_graph
        DeviceGraphs.instance.current
      end

      # Device on which to act
      #
      # @return [Y2Storage::Device]
      def device
        return nil unless device_sid
        working_graph.find_device(device_sid)
      end

      # Actions to perform when the button is clicked
      #
      # @return [Symbol, nil] result of the action, nil if nothing is executed
      def actions
        if actions_class.nil?
          Yast::Popup.Warning("Not yet implemented")
          return nil
        end

        actions_class.new(device).run
      end

      # @return [Actions] an Actions class name to perform the expected actions
      abstract_method :actions_class

      # Checks whether there is a device on which to act
      #
      # @note An error popup is shown when there is no device.
      #
      # @return [Boolean]
      def validate_presence
        return true unless device.nil?

        Yast::Popup.Error(_("No device selected"))
        false
      end
    end
  end
end
