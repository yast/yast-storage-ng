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
require "y2partitioner/widgets/overview"
require "y2partitioner/widgets/partitions_button"

describe Y2Partitioner::Widgets::PartitionsButton do
  before { devicegraph_stub("nested_md_raids") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { current_graph.disks.first }
  let(:pager) { Y2Partitioner::Widgets::OverviewTreePager.new("hostname") }

  subject(:button) { described_class.new(device, pager) }

  describe "#items" do
    context "when targetting a disk" do
      let(:device) { current_graph.disks.first }

      it "returns a list with options to edit, add, delete and clone" do
        expect(button.items).to be_a(Array)
        ids = button.items.map { |item| item.first.to_s.split("_").last }
        expect(ids).to contain_exactly("edit", "add", "delete", "clone")
      end
    end

    context "when targetting a disk" do
      let(:device) { current_graph.raids.first }

      it "returns a list only with options to edit, add and delete" do
        expect(button.items).to be_a(Array)
        ids = button.items.map { |item| item.first.to_s.split("_").last }
        expect(ids).to contain_exactly("edit", "add", "delete")
      end
    end
  end

  describe "#label" do
    it "returns a string with shortcut" do
      expect(button.label).to be_a String
      expect(button.label).to include "&"
    end
  end

  describe "#handle" do
    let(:widget_id) { subject.widget_id }
    let(:event) { { "ID" => selected_option } }
    let(:action) { instance_double("Action", run: nil) }

    RSpec.shared_examples "handle action result" do
      it "returns :redraw if the action returns :finish" do
        allow(action).to receive(:run).and_return :finish
        expect(button.handle(event)).to eq :redraw
      end

      it "returns nil if the action does not return :finish" do
        allow(action).to receive(:run).and_return :back
        expect(button.handle(event)).to be_nil
      end
    end

    context "when the option for editing the partitions is selected" do
      let(:selected_option) { :"#{widget_id}_edit" }

      before do
        allow(Y2Partitioner::Actions::GoToDeviceTab).to receive(:new).and_return action
      end

      it "creates an action to jump to the 'Partitions' tab of the device" do
        expect(Y2Partitioner::Actions::GoToDeviceTab)
          .to receive(:new).with(device, pager, "&Partitions")
        button.handle(event)
      end

      include_examples "handle action result"
    end

    context "when the option for adding a partition is selected" do
      let(:selected_option) { :"#{widget_id}_add" }

      before do
        allow(Y2Partitioner::Actions::AddPartition).to receive(:new).and_return action
      end

      it "opens the workflow for adding a partition" do
        expect(Y2Partitioner::Actions::AddPartition).to receive(:new)
        button.handle(event)
      end

      include_examples "handle action result"
    end

    context "when the option for deleting all partitions is selected" do
      let(:selected_option) { :"#{widget_id}_delete" }

      before do
        allow(Y2Partitioner::Actions::DeletePartitions).to receive(:new).and_return action
      end

      it "calls the action for removing all partitions" do
        expect(Y2Partitioner::Actions::DeletePartitions).to receive(:new)
        button.handle(event)
      end

      include_examples "handle action result"
    end

    context "when the option for clonning the partitions is selected" do
      let(:selected_option) { :"#{widget_id}_clone" }

      before do
        allow(Y2Partitioner::Actions::ClonePartitionTable).to receive(:new).and_return action
      end

      it "calls the action for cloning partitions" do
        expect(Y2Partitioner::Actions::ClonePartitionTable).to receive(:new)
        button.handle(event)
      end

      include_examples "handle action result"
    end
  end
end
