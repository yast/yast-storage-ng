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
require "y2partitioner/device_graphs"
require "y2partitioner/actions/add_lvm_vg"
require "y2partitioner/dialogs/lvm_vg"

describe Y2Partitioner::Actions::AddLvmVg do
  before do
    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)
  end

  subject(:action) { described_class.new }

  describe "#run" do
    context "if there are not enough available devices" do
      before do
        devicegraph_stub("lvm-four-vgs.yml")
      end

      it "shows an error" do
        expect(Yast::Popup).to receive(:Error)
        action.run
      end

      it "quits returning :back" do
        expect(action.run).to eq :back
      end

      it "does not create any vg device in the devicegraph" do
        previous_vgs = Y2Partitioner::DeviceGraphs.instance.current.lvm_vgs
        action.run
        current_vgs = Y2Partitioner::DeviceGraphs.instance.current.lvm_vgs

        expect(current_vgs).to eq(previous_vgs)
      end
    end

    context "if there are enough available devices" do
      before { devicegraph_stub("lvm-two-vgs.yml") }

      context "if the user goes forward through the dialog" do
        before do
          allow(Y2Partitioner::Dialogs::LvmVg).to receive(:run).and_return :next
        end

        it "returns :finish" do
          expect(action.run).to eq :finish
        end

        it "creates a new vg device" do
          previous_vgs = Y2Partitioner::DeviceGraphs.instance.current.lvm_vgs
          action.run
          current_vgs = Y2Partitioner::DeviceGraphs.instance.current.lvm_vgs

          expect(current_vgs.size).to eq(previous_vgs.size + 1)
        end
      end

      context "if the user aborts the process" do
        before do
          allow(Y2Partitioner::Dialogs::LvmVg).to receive(:run).and_return :abort
        end

        it "returns :abort" do
          expect(action.run).to eq :abort
        end

        it "does not create any vg device in the devicegraph" do
          previous_vgs = Y2Partitioner::DeviceGraphs.instance.current.lvm_vgs
          action.run
          current_vgs = Y2Partitioner::DeviceGraphs.instance.current.lvm_vgs

          expect(current_vgs).to eq(previous_vgs)
        end
      end
    end
  end
end
