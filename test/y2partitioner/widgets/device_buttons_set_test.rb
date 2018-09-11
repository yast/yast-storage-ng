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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/device_buttons_set"

describe Y2Partitioner::Widgets::DeviceButtonsSet do
  before do
    devicegraph_stub("md2-devicegraph.xml")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:pager) { Y2Partitioner::Widgets::OverviewTreePager.new("hostname") }

  subject(:widget) { described_class.new(pager) }

  include_examples "CWM::CustomWidget"

  describe "#contents" do
    it "returns an initially empty replace point" do
      contents = widget.contents
      expect(contents.value).to eq :ReplacePoint
      expect(contents.params.last.value).to eq :Empty
    end
  end

  describe "#device=" do
    context "when targeting a partition" do
      let(:device) { device_graph.partitions.first }

      it "replaces the content with buttons to edit, move, resize and delete" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to contain_exactly(
            Y2Partitioner::Widgets::DeviceButtonsSet::ButtonsBox,
            Y2Partitioner::Widgets::BlkDeviceEditButton,
            Y2Partitioner::Widgets::PartitionMoveButton,
            Y2Partitioner::Widgets::DeviceResizeButton,
            Y2Partitioner::Widgets::DeviceDeleteButton
          )
        end

        widget.device = device
      end
    end

    context "when targeting an MD" do
      let(:device) { device_graph.software_raids.first }

      it "replaces the content with buttons to edit, delete and add a partition" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to contain_exactly(
            Y2Partitioner::Widgets::DeviceButtonsSet::ButtonsBox,
            Y2Partitioner::Widgets::BlkDeviceEditButton,
            Y2Partitioner::Widgets::PartitionAddButton,
            Y2Partitioner::Widgets::DeviceDeleteButton
          )
        end

        widget.device = device
      end
    end
  end
end
