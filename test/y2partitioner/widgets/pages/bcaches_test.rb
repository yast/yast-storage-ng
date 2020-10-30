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

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::Bcaches do
  before { devicegraph_stub(scenario) }

  let(:scenario) { "bcache1.xml" }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }

  include_examples "CWM::Page"

  let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }
  let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) } }

  describe "#contents" do
    it "shows a table with the bcache devices and their partitions" do
      expect(table).to_not be_nil

      devices = column_values(table, 0)

      expect(remove_sort_keys(devices)).to contain_exactly("/dev/bcache0", "/dev/bcache1",
        "/dev/bcache2", "bcache0p1", "bcache2p1")
    end
  end

  describe "#state_info" do
    let(:open) { { "id1" => true, "id2" => false } }

    it "returns a hash with the id of the devices table and its corresponding open items" do
      expect(table).to receive(:ui_open_items).and_return open
      expect(subject.state_info).to eq(table.widget_id => open)
    end
  end
end
