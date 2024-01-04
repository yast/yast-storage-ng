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
require_relative "shared_examples"

require "y2partitioner/widgets/columns/caching_device"

describe Y2Partitioner::Widgets::Columns::CachingDevice do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "bcache1.xml" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:bcache_cset) { Y2Storage::Bcache.find_by_name(devicegraph, "/dev/bcache0").bcache_cset }

  before do
    devicegraph_stub(scenario)
  end

  describe "#value_for" do
    context "when the bcache caching set is using a caching device" do
      it "returns the name of device used as caching" do
        expect(subject.value_for(bcache_cset)).to eq("/dev/vdb")
      end
    end

    context "when the bcache caching set is not using a caching device" do
      before do
        allow(bcache_cset).to receive(:blk_devices).and_return([])
      end

      it "returns an empty string" do
        expect(subject.value_for(bcache_cset)).to eq("")
      end
    end
  end
end
