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

require "yast"
require "y2partitioner/widgets/menus/base"

module Y2Partitioner
  module Widgets
    module Menus
      # Abstract class for menus that act upon a given device
      class Device < Base
        # Constructor
        #
        # @param device [Y2Storage::Device, nil] see #device
        def initialize(device)
          textdomain "storage"
          @device_sid = device.sid unless device.nil?
        end

        # @see Base
        #
        # In addition to the implementation of the base class, this includes
        # memoization and handling when the device is nil
        #
        # @return [Array<Symbol>]
        def disabled_items
          @disabled_items ||= device ? disabled_for_device : disabled_without_device
        end

        private

        # @return [Integer] device sid
        attr_reader :device_sid

        # @see Base
        def action_for(event)
          action = "#{event}_action"

          send(action) if respond_to?(action, true)
        end

        # Items to disable if {#device} is not nil
        # @see #disabled_items
        #
        # @return [Array<Symbol>]
        def disabled_for_device
          []
        end

        # Items to disable if {#device} is nil
        # @see #disabled_items
        #
        # @return [Array<Symbol>]
        def disabled_without_device
          items_with_id = items.select do |i|
            i.value == :item && i.params[0].is_a?(Yast::Term) && i.params[0].value == :id
          end
          items_with_id.map { |i| i.params[0].params[0] }
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

        # @see #disabled_for_device
        def multidevice?
          device.is?(:software_raid, :btrfs, :lvm_vg, :bcache)
        end

        # @see #disabled_for_device
        def partitionable?
          device.is?(:software_raid, :disk_device, :bcache)
        end
      end
    end
  end
end
