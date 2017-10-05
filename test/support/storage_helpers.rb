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

require "rspec"
require "yast"
require "storage"
require "y2storage"
require "y2partitioner/device_graphs"

module Yast
  module RSpec
    # RSpec extension to add YaST Storage specific helpers
    module StorageHelpers
      def input_file_for(name, suffix: "yml")
        if suffix
          File.join(DATA_PATH, "devicegraphs", "#{name}.#{suffix}")
        else
          File.join(DATA_PATH, "devicegraphs", name)
        end
      end

      def output_file_for(name)
        File.join(DATA_PATH, "devicegraphs", "output", "#{name}.yml")
      end

      def fake_scenario(scenario)
        if scenario.end_with?(".xml")
          Y2Storage::StorageManager.instance.probe_from_xml(input_file_for(scenario, suffix: nil))
        else
          Y2Storage::StorageManager.instance.probe_from_yaml(input_file_for(scenario))
        end
      end

      # Used when testing the partitioner
      def devicegraph_stub(name)
        # Backwards compatibility, #fake_scenario assumes Yaml by default, but
        # #devicegraph_stub always expects the full file name
        name = name.chomp(".yml")
        fake_scenario(name)

        storage = Y2Storage::StorageManager.instance
        Y2Partitioner::DeviceGraphs.create_instance(storage.probed, storage.staging)
        storage
      end

      def fake_devicegraph
        Y2Storage::StorageManager.instance.probed
      end

      def partition_double(name = "", disk_size = Y2Storage::DiskSize.MiB(10))
        instance_double("Y2Storage::Partition", name: name, size: disk_size)
      end

      def planned_partition(attrs = {})
        part = Y2Storage::Planned::Partition.new(nil)
        add_planned_attributes(part, attrs)
      end

      # Backwards compatibility
      alias_method :planned_vol, :planned_partition

      def planned_vg(attrs = {})
        vg = Y2Storage::Planned::LvmVg.new
        add_planned_attributes(vg, attrs)
      end

      def planned_lv(attrs = {})
        lv = Y2Storage::Planned::LvmLv.new(nil)
        add_planned_attributes(lv, attrs)
      end

      def add_planned_attributes(device, attrs)
        attrs = attrs.dup

        if device.respond_to?(:filesystem_type)
          type = attrs.delete(:type)
          device.filesystem_type =
            if type.is_a?(::String) || type.is_a?(Symbol)
              Y2Storage::Filesystems::Type.const_get(type.to_s.upcase)
            else
              type
            end
        end

        attrs.each_pair do |key, value|
          device.send(:"#{key}=", value)
        end
        device
      end

      def space_dist(vols_by_space)
        Y2Storage::Planned::PartitionsDistribution.new(vols_by_space)
      end
    end
  end
end
