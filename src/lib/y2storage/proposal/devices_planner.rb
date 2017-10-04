#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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

require "y2storage/proposal/devices_planner_strategies"

module Y2Storage
  module Proposal
    #
    # Class to generate the list of planned devices of a proposal
    #
    class DevicesPlanner
      include Yast::Logger

      STRATEGIES = {
        legacy: DevicesPlannerStrategies::Legacy,
        ng:     DevicesPlannerStrategies::NG
      }

      attr_accessor :settings

      def initialize(settings, devicegraph)
        @settings = settings
        @devicegraph = devicegraph
        strategy = @settings.format
        if STRATEGIES[strategy]
          @strategy = STRATEGIES[strategy].new(settings, devicegraph)
        else
          err_msg = "Unsupported device planner strategy :#{strategy}"
          log.error err_msg
          raise ArgumentError, err_msg
        end
      end

      # List of devices (read: partitions or volumes) that need to be
      # created to satisfy the settings.
      #
      # @param target [Symbol] :desired means the sizes of the planned devices
      #   should be the ideal ones, :min for generating the smallest functional
      #   devices
      # @return [Array<Planned::Device>]
      def planned_devices(target)
        @strategy.planned_devices(target)
      end
    end
  end
end
