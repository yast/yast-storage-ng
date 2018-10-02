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
require "cwm"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Abstract base class for a menu button that can perform some actions over
    # a specificic device, e.g. edit, resize, delete, etc.
    #
    # Every subclass should implement {#actions} with the concrete list of
    # actions.
    class DeviceMenuButton < CWM::MenuButton
      # Constructor
      # @param device [Y2Storage::Device]
      def initialize(device)
        textdomain "storage"

        @device_sid = device.sid
        self.handle_all_events = true
      end

      # Runs the corresponding action
      #
      # @param event [Hash] UI event
      # @return [:redraw, nil] :redraw when the action is performed; nil otherwise
      def handle(event)
        return nil unless validate_presence

        action = action_for_widget_id(event["ID"])
        return nil unless action

        action_result(action)
      end

      # @macro seeItemsSelection
      #
      # @return [Array<[Symbol, String]>] list of menu options
      def items
        actions.map do |action|
          [widget_id_for_action(action), action[:label]]
        end
      end

    protected

      # @return [Integer] device sid
      attr_reader :device_sid

      # List of actions to offer in the menu-button
      #
      # Every subclass must implement this method to return an array in which
      # each element is a hash containing:
      #
      #  * :id symbol unique in the list of actions
      #  * :label string to display in the menu-button entry
      #  * :class class of the action to be executed
      #
      # @return [Array<Hash>] bla
      abstract_method :actions

      # Executes the action associated to the corresponding entry in {#actions}
      #
      # It assumes the action class receives a single argument (the device in
      # which to act) in the constructor. If any of the action classes need
      # other arguments, the DeviceMenuButton subclass must override this method
      # to handle that particular situation.
      #
      # @param action [Hash] entry from {#actions}
      # @return [Symbol] result of the action
      def execute_action(action)
        action[:class].new(device).run
      end

      # See {#handle}
      #
      # @param action [Hash]
      # @return [:redraw, nil] :redraw when the action is performed; nil otherwise
      def action_result(action)
        execute_action(action) == :finish ? :redraw : nil
      end

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

      # LibYUI id of the menu-button item associated to the given action
      #
      # @param action [Hash] entry from {#actions}
      # @return [Symbol]
      def widget_id_for_action(action)
        :"#{widget_id}_#{action[:id]}"
      end

      # Entry from {#actions} associated to the given LibYUI id
      #
      # @param id [Symbol, String]
      # @return [Hash, nil] nil if there is no entry in {#actions} associated to
      #   the given id
      def action_for_widget_id(id)
        return nil if id.nil?
        actions.find { |action| widget_id_for_action(action) == id.to_sym }
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
