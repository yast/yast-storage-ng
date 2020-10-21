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
# find current contact information at www.suse.com

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages/btrfs"
require "y2partitioner/widgets/lvm_vg_bar_graph"

describe Y2Partitioner::Widgets::Pages::Btrfs do
  before do
    devicegraph_stub(scenario)
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { current_graph.find_by_name(device_name) }
  let(:filesystem) { device.filesystem }
  let(:pager) { double("Pager") }
  let(:scenario) { "mixed_disks" }
  let(:device_name) { "/dev/sdb2" }

  subject { described_class.new(filesystem, pager) }

  let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }
  let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::ConfigurableBlkDevicesTable) } }
  let(:items) { column_values(table, 0) }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a BTRFS overview tab" do
      expect(Y2Partitioner::Widgets::Pages::FilesystemTab).to receive(:new)

      subject.contents
    end

    it "shows an used devices tab" do
      expect(Y2Partitioner::Widgets::Pages::BtrfsUsedDevicesTab).to receive(:new)

      subject.contents
    end
  end

  describe Y2Partitioner::Widgets::Pages::FilesystemTab do
    subject { described_class.new(filesystem, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      it "contains no graph bar" do
        disk_bar = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DiskBarGraph) }
        lvm_bar = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmVgBarGraph) }
        expect(disk_bar).to be_nil
        expect(lvm_bar).to be_nil
      end

      it "shows a table containing only the RAID" do
        expect(table).to_not be_nil

        expect(remove_sort_keys(items)).to eq ["sdb2"]
      end
    end
  end

  describe Y2Partitioner::Widgets::Pages::BtrfsUsedDevicesTab do
    subject { described_class.new(filesystem, pager) }
    let(:pager) { double("Y2Partitioner::Widgets::OverviewTreePager") }

    include_examples "CWM::Tab"

    describe "#contents" do
      it "shows a table with the BtrFS and its devices" do
        expect(table).to_not be_nil

        expect(remove_sort_keys(items)).to contain_exactly(
          "BtrFS",
          "/dev/sdb2"
        )
      end

      it "shows a button for editing the Btrfs devices" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::UsedDevicesEditButton) }
        expect(button).to_not be_nil
      end
    end
  end
end
