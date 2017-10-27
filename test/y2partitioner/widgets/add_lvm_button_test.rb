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
require "y2partitioner/widgets/add_lvm_button"

describe Y2Partitioner::Widgets::AddLvmButton do
  before do
    devicegraph_stub("lvm-two-vgs.yml")
  end

  subject(:button) { described_class.new(table) }

  let(:table) { double("table", selected_device: selected_device) }

  let(:selected_device) { nil }

  include_examples "CWM::AbstractWidget"

  describe "#items" do
    it "returns a list" do
      expect(button.items).to be_a(Array)
    end

    context "when there are vgs in the system" do
      it "includes option for adding a vg" do
        expect(button.items.map(&:first)).to include(:add_volume_group)
      end

      it "includes option for adding a lv" do
        expect(button.items.map(&:first)).to include(:add_logical_volume)
      end
    end

    context "when there are no vgs in the system" do
      before do
        allow(Y2Partitioner::DeviceGraphs.instance.current).to receive(:lvm_vgs).and_return([])
      end

      it "includes option for adding a vg" do
        expect(button.items.map(&:first)).to include(:add_volume_group)
      end

      it "does not include option for adding a lv" do
        expect(button.items.map(&:first)).to_not include(:add_logical_volume)
      end
    end
  end

  describe "#handle" do
    before do
      allow(Y2Partitioner::Sequences::AddLvmLv).to receive(:new).and_return sequence
    end

    let(:sequence) { double("AddLvmLv", run: :result) }

    let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

    let(:lv) { vg.lvm_lvs.first }

    let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

    let(:event) { { "ID" => selected_option } }

    context "when a vg is selected in the table" do
      let(:selected_device) { vg }

      context "and option for adding vg is selected" do
        let(:selected_option) { :add_volume_group }

        xit "opens the workflow for adding a new vg" do
        end
      end

      context "and option for adding lv is selected" do
        let(:selected_option) { :add_logical_volume }

        it "opens the workflow for adding a new lv to the vg" do
          expect(Y2Partitioner::Sequences::AddLvmLv).to receive(:new).with(vg)
          button.handle(event)
        end

        it "returns :redraw if the workflow returns :finish" do
          allow(sequence).to receive(:run).and_return :finish
          expect(button.handle(event)).to eq :redraw
        end

        it "returns nil if the workflow does not return :finish" do
          allow(sequence).to receive(:run).and_return :back
          expect(button.handle(event)).to be_nil
        end
      end
    end

    context "when a lv is selected in the table" do
      let(:selected_device) { lv }

      context "and option for adding vg is selected" do
        let(:selected_option) { :add_volume_group }

        xit "opens the workflow for adding a new vg" do
        end
      end

      context "and option for adding lv is selected" do
        let(:selected_option) { :add_logical_volume }

        it "opens the workflow for adding a new lv to its vg" do
          expect(Y2Partitioner::Sequences::AddLvmLv).to receive(:new).with(vg)
          button.handle(event)
        end

        it "returns :redraw if the workflow returns :finish" do
          allow(sequence).to receive(:run).and_return :finish
          expect(button.handle(event)).to eq :redraw
        end

        it "returns nil if the workflow does not return :finish" do
          allow(sequence).to receive(:run).and_return :back
          expect(button.handle(event)).to be_nil
        end
      end
    end

    context "when no device is selected in the table" do
      let(:selected_device) { nil }

      context "and option for adding lv is selected" do
        let(:selected_option) { :add_logical_volume }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          button.handle(event)
        end

        it "returns nil" do
          allow(Yast::Popup).to receive(:Error)
          expect(button.handle(event)).to be_nil
        end
      end
    end
  end
end
