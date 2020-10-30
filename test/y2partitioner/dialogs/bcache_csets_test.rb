#!/usr/bin/env rspec

# Copyright (c) [2018-2020] SUSE LLC
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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/bcache_csets"

describe Y2Partitioner::Dialogs::BcacheCsets do
  before { devicegraph_stub(scenario) }

  let(:scenario) { "bcache1.xml" }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new }

  let(:bcaches) { device_graph.bcaches }

  include_examples "CWM::Dialog"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "contains a table for the Bcache Caching Sets" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::BcacheCsets::BcacheCsetsTable)
      end

      expect(widget).to_not(be_nil)
    end
  end

  describe Y2Partitioner::Dialogs::BcacheCsets::BcacheCsetsTable do
    subject { described_class.new }

    before do
      vda1 = device_graph.find_by_name("/dev/vda1")
      vda1.create_bcache_cset
    end

    include_examples "CWM::CustomWidget"

    describe "#items" do
      it "contains all the Bcache Caching Sets" do
        devices = column_values(subject, 0)

        expect(devices).to contain_exactly("/dev/vdb", "/dev/vda1")
      end
    end
  end
end
