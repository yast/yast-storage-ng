# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

module Yast
  module RSpec
    # RSpec extension to add YaST Storage specific helpers
    module StorageHelpers
      def input_file_for(name)
        File.join(DATA_PATH, "devicegraphs", "#{name}.yml")
      end

      def output_file_for(name)
        File.join(DATA_PATH, "devicegraphs", "output", "#{name}.yml")
      end

      def fake_scenario(scenario)
        Y2Storage::StorageManager.fake_from_yaml(input_file_for(scenario))
      end

      def fake_devicegraph
        Y2Storage::StorageManager.instance.y2storage_probed
      end

      def analyzer_part(name = "", disk_size = Y2Storage::DiskSize.MiB(10))
        instance_double("::Storage::Partition", name: name, size: disk_size)
      end

      def planned_vol(attrs = {})
        attrs = attrs.dup
        mount_point = attrs.delete(:mount_point)
        type = attrs.delete(:type)
        if type.is_a?(::String) || type.is_a?(Symbol)
          type = Y2Storage::Filesystems::Type.const_get(type.to_s.upcase)
        end
        volume = Y2Storage::PlannedVolume.new(mount_point, type)
        attrs.each_pair do |key, value|
          volume.send(:"#{key}=", value)
        end
        volume
      end

      def space_dist(vols_by_space)
        Y2Storage::Proposal::SpaceDistribution.new(vols_by_space)
      end

      def vols_list(*vols)
        Y2Storage::PlannedVolumesList.new([*vols])
      end
    end
  end
end
