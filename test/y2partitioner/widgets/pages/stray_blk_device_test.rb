#!/usr/bin/env rspec
# Copyright (c) [2018-2019] SUSE LLC
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
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::StrayBlkDevice do
  before { devicegraph_stub("xen-partitions.xml") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { current_graph.stray_blk_devices.first }
  let(:pager) { double("Pager") }

  subject { described_class.new(device, pager) }

  let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }
  let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::ConfigurableBlkDevicesTable) } }
  let(:items) { column_values(table, 0) }

  include_examples "CWM::Page"

  describe "#contents" do
    it "shows a generic device overview tab" do
      expect(Y2Partitioner::Widgets::OverviewTab).to receive(:new)
      subject.contents
    end
  end

  describe Y2Partitioner::Widgets::OverviewTab do
    subject { described_class.new(device, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      it "shows a table containing only the device" do
        expect(table).to_not be_nil

        expect(items).to eq ["/dev/xvda1"]
      end
    end
  end
end
