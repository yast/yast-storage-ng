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
require "y2partitioner/widgets/partitions_delete_button"

describe Y2Partitioner::Widgets::PartitionsDeleteButton do
  before do
    devicegraph_stub(scenario)
  end

  subject(:button) { described_class.new(device: device) }

  let(:device) { device_graph.find_by_name(device_name) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks" }

  let(:device_name) { "/dev/sda" }

  include_examples "CWM::PushButton"

  describe "#handle" do
    before do
      allow(Y2Partitioner::Actions::DeletePartitions).to receive(:new).and_return(action)
    end

    let(:action) { instance_double(Y2Partitioner::Actions::DeletePartitions, run: :finish) }

    it "calls the action to delete all partitions" do
      expect(Y2Partitioner::Actions::DeletePartitions).to receive(:new).with(device)

      button.handle
    end

    it "returns :redraw if the action was successful" do
      allow(action).to receive(:run).and_return(:finish)

      expect(button.handle).to eq(:redraw)
    end

    it "returns nil if the action was not successful" do
      allow(action).to receive(:run).and_return(:back)

      expect(button.handle).to be_nil
    end
  end
end
