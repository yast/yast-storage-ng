#!/usr/bin/env rspec
# encoding: utf-8
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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/bcache_modify_button"

describe Y2Partitioner::Widgets::BcacheModifyButton do
  before { devicegraph_stub("bcache1.xml") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { current_graph.bcaches.first }

  subject(:button) { described_class.new(device) }

  describe "#items" do
    it "returns a list" do
      expect(button.items).to be_a(Array)
    end
  end

  describe "#label" do
    it "returns a string with keyboard shortcut" do
      expect(button.label).to be_a String
      expect(button.label).to include "&"
    end
  end

  describe "#handle" do
    let(:widget_id) { subject.widget_id }
    let(:event) { { "ID" => selected_option } }
    let(:action) { instance_double("Action", run: nil) }

    RSpec.shared_examples "handle bcache action result" do
      it "returns :redraw if the workflow returns :finish" do
        allow(action).to receive(:run).and_return :finish
        expect(button.handle(event)).to eq :redraw
      end

      it "returns nil if the workflow does not return :finish" do
        allow(action).to receive(:run).and_return :back
        expect(button.handle(event)).to be_nil
      end
    end

    context "when the option for editing the bcache is selected" do
      let(:selected_option) { :"#{widget_id}_edit" }

      before do
        allow(Y2Partitioner::Actions::EditBlkDevice).to receive(:new).and_return action
      end

      it "opens the workflow for editing the device" do
        expect(Y2Partitioner::Actions::EditBlkDevice).to receive(:new)
        button.handle(event)
      end

      include_examples "handle bcache action result"
    end

    context "when the option for changing the caching is selected" do
      let(:selected_option) { :"#{widget_id}_caching" }

      before do
        allow(Y2Partitioner::Actions::EditBcache).to receive(:new).and_return action
      end

      it "opens the workflow for changing the caching options" do
        expect(Y2Partitioner::Actions::EditBcache).to receive(:new)
        button.handle(event)
      end

      include_examples "handle bcache action result"
    end

    context "when the option for creating a partition table is selected" do
      let(:selected_option) { :"#{widget_id}_ptable" }

      before do
        allow(Y2Partitioner::Actions::CreatePartitionTable).to receive(:new).and_return action
      end

      it "opens the action for creating the partition table" do
        expect(Y2Partitioner::Actions::CreatePartitionTable).to receive(:new)
        button.handle(event)
      end

      include_examples "handle bcache action result"
    end
  end
end
