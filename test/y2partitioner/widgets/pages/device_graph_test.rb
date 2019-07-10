#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/device_graphs"

describe Y2Partitioner::Widgets::Pages::DeviceGraph do
  before do
    devicegraph_stub("complex-lvm-encrypt")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject(:page) { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }
  let(:system) { Y2Partitioner::DeviceGraphs.instance.system }
  let(:current) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::Page"

  describe "#contents" do
    it "includes a tab for the current graph and another for the system one" do
      expect(Y2Partitioner::Widgets::Pages::DeviceGraphTab).to receive(:new)
        .with("Planned Devices", current, any_args)
      expect(Y2Partitioner::Widgets::Pages::DeviceGraphTab).to receive(:new)
        .with("Current System Devices", system, any_args)
      page.contents
    end
  end

  describe Y2Partitioner::Widgets::Pages::DeviceGraphTab do
    let(:device_graph_widget) { double("DeviceGraphWithButtons") }
    let(:device_graph) { double("Devicegraph") }

    subject(:widget) { described_class.new("Label", device_graph, "Description", pager) }

    include_examples "CWM::Tab"

    describe "#label" do
      it "returns the correct label" do
        expect(widget.label).to eq "Label"
      end
    end

    describe "#contents" do
      it "includes the description and the graph widget" do
        expect(Y2Partitioner::Widgets::DeviceGraphWithButtons).to receive(:new)
          .with(device_graph, pager).and_return device_graph_widget
        contents = widget.contents

        found = contents.nested_find { |i| i == device_graph_widget }
        expect(found).to_not be_nil
        found = contents.nested_find { |i| i.respond_to?(:params) && i.params == ["Description"] }
        expect(found).to_not be_nil
      end
    end
  end
end
