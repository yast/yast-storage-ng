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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/partition_add_button"

describe Y2Partitioner::Widgets::PartitionAddButton do
  subject { described_class.new(device: device, pager: pager) }

  let(:device) { nil }

  let(:pager) do
    instance_double(Y2Partitioner::Widgets::OverviewTreePager)
  end

  include_examples "CWM::PushButton"

  describe "#handle" do
    context "when no device is given" do
      let(:device) { nil }

      it "shows an error message" do
        expect(Yast::Popup).to receive(:Error)
        subject.handle
      end

      it "returns nil" do
        expect(subject.handle).to be(nil)
      end
    end

    context "when a device is given" do
      before do
        devicegraph_stub(scenario)
        allow(action_class).to receive(:new).with(device).and_return(action)
      end

      let(:scenario) { "one-empty-disk.yml" }

      let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

      let(:device) { current_graph.disks.first }

      let(:action) { instance_double(action_class) }

      let(:action_class) { Y2Partitioner::Actions::AddPartition }

      context "and the device is a disk device" do
        it "performs the action for adding a partition over the disk device" do
          expect(action_class).to receive(:new).with(device).and_return(action)
          expect(action).to receive(:run)
          subject.handle
        end
      end

      context "and the device is a partition" do
        let(:scenario) { "mixed_disks.yml" }

        let(:device) { Y2Storage::Partition.find_by_name(current_graph, "/dev/sda1") }

        let(:disk) { device.partitionable }

        before do
          allow(device).to receive(:partitionable).and_return(disk)
        end

        it "performs the action for adding a partition over the partition's disk device" do
          expect(action_class).to receive(:new).with(disk).and_return(action)
          expect(action).to receive(:run)
          subject.handle
        end
      end

      it "returns :redraw if the add action returns :finish" do
        allow(action).to receive(:run).and_return(:finish)
        expect(subject.handle).to eq(:redraw)
      end

      it "returns nil if the add action does not return :finish" do
        allow(action).to receive(:run).and_return(:back)
        expect(subject.handle).to be_nil
      end
    end
  end
end
