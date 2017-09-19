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
require "y2storage"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Sequences
    # This class stores information about an MD RAID being created or modified
    # and takes care of updating the devicegraph when needed, so the different
    # dialogs can always work directly on a real Md object in the devicegraph.
    class MdController
      # @return [Array<Y2Storage::Partition>]
      def available_devices
        working_graph.partitions.select { |part| available?(part) }
      end

      # @return [Y2Storage::Md]
      def md
        @md ||=
          begin
            name = Y2Storage::Md.find_free_numeric_name(working_graph)
            Y2Storage::Md.create(working_graph, name)
          end
      end

      def devices=(devices)
        md.devices.each { |dev| md.remove_device(dev) }
        devices.each do |dev|
          dev = dev.encryption if dev.encrypted?
          dev.remove_descendants
          md.add_device(dev)
        end
      end

    private

      def working_graph
        DeviceGraphs.instance.current
      end

      def available?(partition)
        return false unless partition.id.is?(:linux_system)
        return false if partition.lvm_pv
        return false if partition.md
        return true if partition.filesystem.nil?

        mount = partition.filesystem.mountpoint
        mount.nil? || mount.empty?
      end
    end
  end
end
