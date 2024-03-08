#!/usr/bin/env rspec

# Copyright (c) [2020-2024] SUSE LLC
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

require_relative "../../test_helper"
require_relative "./shared_examples"

require "y2partitioner/widgets/columns/filesystem_label"

describe Y2Partitioner::Widgets::Columns::FilesystemLabel do

  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "mixed_disks" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, device_name) }
  let(:device_name) { "/dev/sdb2" }

  before do
    devicegraph_stub(scenario)
  end

  describe "#value_for" do
    it "includes the filesystem label" do
      expect(subject.value_for(device)).to eq("suse_root")
    end
  end
end
