#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../test_helper"
require "y2partitioner/actions/resize_partition"
require "y2partitioner/dialogs/partition_resize"
require "y2partitioner/device_graphs"

describe Y2Partitioner::Actions::ResizePartition do
  using Y2Storage::Refinements::SizeCasts

  before do
    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)

    devicegraph_stub(scenario)
    allow(partition).to receive(:detect_resize_info).and_return(resize_info)
  end

  subject(:action) { described_class.new(partition) }

  let(:scenario) { "mixed_disks.yml" }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:partition) { Y2Storage::Partition.find_by_name(current_graph, "/dev/sda1") }

  let(:resize_info) do
    instance_double(Y2Storage::ResizeInfo,
      resize_ok?: can_resize,
      min_size:   min_size,
      max_size:   max_size)
  end

  let(:can_resize) { nil }

  let(:min_size) { 100.KiB }

  let(:max_size) { 1.GiB }

  describe "#run" do
    context "when the partition cannot be resized" do
      let(:can_resize) { false }

      it "shows an error popup" do
        expect(Yast::Popup).to receive(:Error)
        action.run
      end

      it "returns :back" do
        expect(action.run).to eq(:back)
      end
    end

    context "when the partition can be resized" do
      let(:can_resize) { true }

      context "and the user goes forward in the dialog" do
        before do
          allow(Y2Partitioner::Dialogs::PartitionResize).to receive(:run).and_return(:next)
        end

        it "returns :finish" do
          expect(action.run).to eq(:finish)
        end
      end

      context "and the user aborts the process" do
        before do
          allow(Y2Partitioner::Dialogs::PartitionResize).to receive(:run).and_return(:abort)
        end

        it "returns :abort" do
          expect(action.run).to eq(:abort)
        end
      end
    end
  end
end
