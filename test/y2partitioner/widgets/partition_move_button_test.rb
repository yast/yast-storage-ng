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
require "y2partitioner/widgets/partition_move_button"

describe Y2Partitioner::Widgets::PartitionMoveButton do
  before do
    devicegraph_stub("mixed_disks")

    allow(Y2Partitioner::Actions::MovePartition).to receive(:new).and_return move_action
    allow(move_action).to receive(:run)
  end

  let(:move_action) { instance_double(Y2Partitioner::Actions::MovePartition) }

  subject { described_class.new(device: partition) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:partition) { current_graph.find_by_name("/dev/sda1") }

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "returns :redraw if the move action returns :finish" do
      allow(move_action).to receive(:run).and_return(:finish)
      expect(subject.handle).to eq(:redraw)
    end

    it "returns nil if the move action does not return :finish" do
      allow(move_action).to receive(:run).and_return(:back)
      expect(subject.handle).to be_nil
    end
  end
end
