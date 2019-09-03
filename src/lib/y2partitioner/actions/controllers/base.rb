# Copyright (c) [2018-2019] SUSE LLC
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

require "y2partitioner/device_graphs"

module Y2Partitioner
  module Actions
    module Controllers
      # Base class for most Y2Partitioner controllers
      class Base
        private

        # System devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def system_graph
          DeviceGraphs.instance.system
        end

        # Current devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def current_graph
          DeviceGraphs.instance.current
        end

        alias_method :working_graph, :current_graph

        # Disk analyzer for the system devicegraph
        #
        # @return [Y2Storage::DiskAnalyzer]
        def disk_analyzer
          DeviceGraphs.instance.disk_analyzer
        end

        # Checks whether the given devicegraph has been added during this execution
        # of the Partitioner or whether it already existed when the Partitioner
        # was started.
        #
        # @param device [Y2Storage::Device]
        # @return [Boolean] true if the device was already there in the
        #   system devicegraph
        def new?(device)
          !device.exists_in_devicegraph?(system_graph)
        end

        # Equivalent to the given device in the system devicegraph, if any
        #
        # @param device [Y2Storage::Device]
        # @return [Y2Storage::Device, nil] system version of the given device,
        #   nil if the device does not exist on the real system
        def system_device(device)
          system_graph.find_device(device.sid)
        end
      end
    end
  end
end
