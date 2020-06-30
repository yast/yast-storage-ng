#!/usr/bin/env rspec
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

require_relative "../../test_helper"
require_relative "./shared_examples"

require "y2partitioner/widgets/columns/used_by"

describe Y2Partitioner::Widgets::Columns::UsedBy do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "bcache1.xml" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:bcache_cset) { Y2Storage::Bcache.find_by_name(devicegraph, "/dev/bcache0").bcache_cset }

  before do
    devicegraph_stub(scenario)
  end

  describe "#value_for" do
    it "returns a string containing all the bcaches devices using the caching set" do
      bcaches = subject.value_for(bcache_cset)

      expect(bcaches).to include("/dev/bcache0")
      expect(bcaches).to include("/dev/bcache1")
      expect(bcaches).to include("/dev/bcache2")
    end
  end
end
