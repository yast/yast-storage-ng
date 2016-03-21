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
require "storage/fake_probing"
require "storage/fake_device_factory"

module Yast
  module RSpec
    # RSpec extension to add YaST Storage specific helpers
    module StorageHelpers
      def input_file_for(name)
        File.join(DATA_PATH, "input", "#{name}.yml")
      end

      def output_file_for(name)
        File.join(DATA_PATH, "output", "#{name}.yml")
      end

      def fake_scenario(scenario)
        @fake_probing = Yast::Storage::FakeProbing.new
        devicegraph = @fake_probing.devicegraph
        Yast::Storage::FakeDeviceFactory.load_yaml_file(devicegraph, input_file_for(scenario))
      end

      def fake_to_probed
        @fake_probing.to_probed
      end

      def fake_devicegraph
        @fake_probing.devicegraph
      end
    end
  end
end
