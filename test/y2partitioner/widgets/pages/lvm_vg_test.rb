#!/usr/bin/env rspec

# Copyright (c) [2017-2020] SUSE LLC
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

require_relative "device_page"
require "y2partitioner/widgets/pages/lvm_vg"

describe Y2Partitioner::Widgets::Pages::LvmVg do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  subject { described_class.new(lvm_vg, pager) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:lvm_vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }
  let(:pager) { double("Pager") }

  include_examples "CWM::Page"

  include_examples(
    "device page",
    "Y2Partitioner::Widgets::Pages::LvmVgTab",
    "Y2Partitioner::Widgets::Pages::LvmPvTab"
  )

  let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }
  let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmDevicesTable) } }
  let(:items) { column_values(table, 0) }

  describe "#contents" do
    it "shows a vg tab" do
      expect(Y2Partitioner::Widgets::Pages::LvmVgTab).to receive(:new)
      subject.contents
    end

    it "shows a pvs tab" do
      expect(Y2Partitioner::Widgets::Pages::LvmPvTab).to receive(:new)
      subject.contents
    end
  end

  describe Y2Partitioner::Widgets::Pages::LvmVgTab do
    subject { described_class.new(lvm_vg, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      before do
        create_thin_provisioning(lvm_vg)
      end

      it "contains a graph bar" do
        bar = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmVgBarGraph) }
        expect(bar).to_not be_nil
      end

      it "shows a table with the vg and its lvs (including thin volumes)" do
        expect(table).to_not be_nil

        expect(items).to contain_exactly(
          "/dev/vg0",
          "lv1",
          "lv2",
          "pool1",
          "thin1",
          "thin2",
          "pool2",
          "thin3"
        )
      end
    end
  end

  describe Y2Partitioner::Widgets::Pages::LvmPvTab do
    subject { described_class.new(lvm_vg, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::ConfigurableBlkDevicesTable) } }

      let(:items) { column_values(table, 0) }

      it "shows a table with the vg and its pvs" do
        expect(table).to_not be_nil

        expect(remove_sort_keys(items)).to contain_exactly(
          "/dev/vg0",
          "/dev/sda7"
        )
      end

      it "shows a button for editing the pvs" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmVgResizeButton) }
        expect(button).to_not be_nil
      end
    end
  end
end
