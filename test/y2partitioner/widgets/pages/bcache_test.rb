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
require "y2partitioner/widgets/pages/bcache"

describe Y2Partitioner::Widgets::Pages::Bcache do
  before do
    devicegraph_stub(scenario)
  end

  let(:scenario) { "bcache2.xml" }
  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:bcache) { current_graph.find_by_name(device_name) }
  let(:device_name) { "/dev/bcache0" }
  let(:pager) { double("Pager") }

  subject { described_class.new(bcache, pager) }

  let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }
  let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::ConfigurableBlkDevicesTable) } }
  let(:items) { table.items.map { |i| i[1] } }

  include_examples "CWM::Page"

  describe "#contents" do
    it "shows a bcache overview tab" do
      expect(Y2Partitioner::Widgets::Pages::BcacheTab).to receive(:new)
      subject.contents
    end

    it "shows an used devices tab" do
      expect(Y2Partitioner::Widgets::Pages::BcacheUsedDevicesTab).to receive(:new)
      subject.contents
    end
  end

  describe Y2Partitioner::Widgets::Pages::BcacheTab do
    subject { described_class.new(bcache, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      it "contains a graph bar" do
        bar = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DiskBarGraph) }
        expect(bar).to_not be_nil
      end

      context "when the bcache device contains no partitions" do
        it "shows a table containing only the bcache" do
          expect(table).to_not be_nil

          expect(remove_sort_keys(items)).to eq ["/dev/bcache0"]
        end
      end

      context "when the bcache device is partitioned" do
        let(:device_name) { "/dev/bcache1" }

        it "shows a table with the bcache and its partitions" do
          expect(table).to_not be_nil

          expect(remove_sort_keys(items)).to contain_exactly(
            "/dev/bcache1", "/dev/bcache1p1", "/dev/bcache1p2"
          )
        end
      end
    end
  end

  describe Y2Partitioner::Widgets::Pages::BcacheUsedDevicesTab do
    subject { described_class.new(bcache, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      it "shows a table with the Bcache, its backing and its caching devices" do
        expect(table).to_not be_nil

        expect(remove_sort_keys(items)).to contain_exactly(
          "/dev/bcache0",
          "/dev/sdb2",
          "/dev/sdb1"
        )
      end

      it "shows a button for editing the Bcache device" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BcacheEditButton) }
        expect(button).to_not be_nil
      end
    end
  end
end
