#!/usr/bin/env rspec

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

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages/lvm"

describe Y2Partitioner::Widgets::Pages::Lvm do
  before do
    devicegraph_stub(scenario)
  end

  let(:scenario) { "lvm-two-vgs.yml" }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmDevicesTable) } }

    let(:items) { table.items.map { |i| i[1] } }

    before do
      vg = Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0")
      create_thin_provisioning(vg)
    end

    it "shows a table with the vgs devices and their lvs (including thin volumes)" do
      expect(table).to_not be_nil

      expect(items).to contain_exactly(
        "/dev/vg0",
        "/dev/vg0/lv1",
        "/dev/vg0/lv2",
        "/dev/vg0/pool1",
        "/dev/vg0/thin1",
        "/dev/vg0/thin2",
        "/dev/vg0/pool2",
        "/dev/vg0/thin3",
        "/dev/vg1",
        "/dev/vg1/lv1"
      )
    end

    it "shows a menu button to create a new VG" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmVgAddButton) }
      expect(button).to_not be_nil
    end
  end
end
