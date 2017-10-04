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

require "y2storage/boot_requirements_checker"

module Y2Storage
  module Proposal
    module DevicesPlannerStrategies
      #
      # Class to generate the list of planned devices of a proposal
      #
      class NG
        include Yast::Logger

        def initialize(settings, devicegraph)
          @settings = settings
          @devicegraph = devicegraph
        end

        # List of devices (read: partitions or volumes) that need to be
        # created to satisfy the settings.
        #
        # @param target [Symbol] :desired means the sizes of the planned devices
        #   should be the ideal ones, :min for generating the smallest functional
        #   devices
        # @return [Array<Planned::Device>]
        def planned_devices(target)
          @target = target
          devices = []
          checker = BootRequirementsChecker.new(@devicegraph, planned_devices: devices)
          devices += checker.needed_partitions
          devices
        end
      end
    end
  end
end
