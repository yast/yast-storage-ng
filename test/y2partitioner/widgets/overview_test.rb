#!/usr/bin/env rspec
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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/overview"

describe Y2Partitioner::Widgets::OverviewTreePager do
  before do
    devicegraph_stub("lvm-two-vgs.yml")
  end

  subject { described_class.new("hostname") }

  include_examples "CWM::Pager"

  describe "#device_page" do
    let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

    let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

    context "when there is a page associated to the requested device" do
      let(:device) { vg }

      it "returns the page" do
        page = subject.device_page(device)
        expect(page).to be_a(CWM::Page)
        expect(page.device).to eq(device)
      end
    end

    context "when there is not a page associated to the requested device" do
      let(:device) { vg.lvm_pvs.first }

      it "returns nil" do
        page = subject.device_page(device)
        expect(page).to be_nil
      end
    end
  end
end
