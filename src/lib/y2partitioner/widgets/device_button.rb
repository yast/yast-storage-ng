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

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Base class for a button that performs some action over a specificic device,
    # e.g., edit, resize, delete, etc.
    class DeviceButton < CWM::PushButton
      # Constructor
      # @param pager [CWM::TreePager]
      # @param table [Y2Partitioner::Widgets::ConfigurableBlkDevicesTable]
      # @param device [Y2Storage::Device]
      def initialize(pager: nil, table: nil, device: nil)
        textdomain "storage"

        @pager = pager
        @table = table
        @device_sid = device.sid unless device.nil?
      end

      # @macro seeAbstractWidget
      def handle
        return nil unless validate_presence
        actions
      end

    protected

      # @return [CWM::TreePager]
      attr_reader :pager

      # @return [Y2Partitioner::Widgets::ConfigurableBlkDevicesTable]
      attr_reader :table

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
        if device_sid
          working_graph.find_device(device_sid)
        elsif table
          table.selected_device
        end
      end

      # Actions to perform when the button is clicked
      #
      # @return [:redraw, nil] :redraw when the action is performed; nil otherwise
      def actions
        if actions_class.nil?
          Yast::Popup.Warning("Not yet implemented")
          return nil
        end

        actions_result = actions_class.new(device).run
        result(actions_result)
      end

      # @return [Actions] an Actions class name to perform the expected actions
      abstract_method :actions_class

      # By default, it returns :redraw when the action is performed; nil otherwise
      #
      # @return [:redraw, nil]
      def result(actions_result)
        actions_result == :finish ? :redraw : nil
      end

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
