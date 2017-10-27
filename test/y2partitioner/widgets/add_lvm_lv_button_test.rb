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
require "y2partitioner/widgets/add_lvm_lv_button"

describe Y2Partitioner::Widgets::AddLvmLvButton do
  before do
    devicegraph_stub("lvm-two-vgs.yml")
  end

  subject(:button) { described_class.new(vg) }

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::PushButton"

  describe "#handle" do
    before do
      allow(Y2Partitioner::Sequences::AddLvmLv).to receive(:new).and_return sequence
    end

    let(:sequence) { double("AddLvmLv", run: :result) }

    it "opens the workflow for adding a new lv to the vg" do
      expect(Y2Partitioner::Sequences::AddLvmLv).to receive(:new).with(vg)
      button.handle
    end

    it "returns :redraw if the workflow returns :finish" do
      allow(sequence).to receive(:run).and_return :finish
      expect(button.handle).to eq :redraw
    end

    it "returns nil if the workflow does not return :finish" do
      allow(sequence).to receive(:run).and_return :back
      expect(button.handle).to be_nil
    end
  end
end
