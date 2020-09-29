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

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages/md_raid"

describe Y2Partitioner::Widgets::Pages::MdRaid do
  before { devicegraph_stub(scenario) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:pager) { double("Pager") }
  let(:scenario) { "md_raid" }
  let(:md) { current_graph.md_raids.first }

  subject { described_class.new(md, pager) }

  let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }
  let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::ConfigurableBlkDevicesTable) } }
  let(:items) { table.items.map { |i| i[1] } }

  include_examples "CWM::Page"

  describe "#contents" do
    it "shows a MD tab" do
      expect(Y2Partitioner::Widgets::Pages::MdTab).to receive(:new).with(md, pager, anything)
      subject.contents
    end

    it "shows a used devices tab" do
      expect(Y2Partitioner::Widgets::UsedDevicesTab).to receive(:new).with(md, pager)
      subject.contents
    end
  end

  describe Y2Partitioner::Widgets::Pages::MdTab do
    subject { described_class.new(md, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      it "contains a graph bar" do
        bar = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DiskBarGraph) }
        expect(bar).to_not be_nil
      end

      context "when the MD contains no partitions" do
        it "shows a table containing only the RAID" do
          expect(table).to_not be_nil

          expect(remove_sort_keys(items)).to eq ["/dev/md/md0"]
        end
      end

      context "when the MD is partitioned" do
        let(:scenario) { "partitioned_md_raid.xml" }

        it "shows a table with the RAID and its partitions" do
          expect(table).to_not be_nil

          expect(remove_sort_keys(items)).to contain_exactly(
            "/dev/md/md0", "/dev/md/md0p1"
          )
        end
      end
    end
  end

  describe Y2Partitioner::Widgets::Pages::MdUsedDevicesTab do
    subject { described_class.new(md, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      it "shows a table with the MD RAID and its devices" do
        expect(table).to_not be_nil

        expect(remove_sort_keys(items)).to contain_exactly(
          "/dev/md/md0",
          "/dev/sda1",
          "/dev/sda2"
        )
      end

      it "shows a button to edit the devices of the MD RAID" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::UsedDevicesEditButton) }
        expect(button).to_not be_nil
      end
    end
  end
end
