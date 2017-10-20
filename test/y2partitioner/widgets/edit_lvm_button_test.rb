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
require "y2partitioner/widgets/edit_lvm_button"

describe Y2Partitioner::Widgets::EditLvmButton do
  before do
    devicegraph_stub("lvm-two-vgs.yml")
  end

  subject(:button) { described_class.new(pager: pager, table: table) }

  let(:table) { double("table", selected_device: device) }

  let(:device) { nil }

  let(:pager) { instance_double(Y2Partitioner::Widgets::OverviewTreePager) }

  include_examples "CWM::PushButton"

  describe "#handle" do
    before do
      allow(Y2Partitioner::Sequences::EditBlkDevice).to receive(:new).and_return sequence
    end

    let(:sequence) { double("EditBlkDevice", run: :result) }

    let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

    let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

    let(:lv) { vg.lvm_lvs.first }

    context "when the current device is a vg" do
      let(:device) { vg }

      before do
        allow(pager).to receive(:device_page).with(vg).and_return(page)
      end

      let(:page) { double("page", label: "vg_page") }

      it "jumps to the vg page" do
        expect(Y2Partitioner::UIState.instance).to receive(:go_to_tree_node).with(page)
        button.handle
      end

      it "returns :redraw" do
        expect(button.handle).to eq :redraw
      end
    end

    context "when the current device is a lv" do
      let(:device) { lv }

      it "opens the workflow for editing the lv" do
        expect(Y2Partitioner::Sequences::EditBlkDevice).to receive(:new).with(lv)
        button.handle
      end

      it "returns :redraw" do
        expect(button.handle).to eq :redraw
      end
    end
  end
end
