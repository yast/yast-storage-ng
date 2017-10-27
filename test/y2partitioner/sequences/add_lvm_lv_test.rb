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
require "y2partitioner/sequences/add_lvm_lv"
require "y2partitioner/dialogs/lvm_lv_info"
require "y2partitioner/dialogs/lvm_lv_size"
require "y2partitioner/dialogs/partition_role"
require "y2partitioner/dialogs/format_and_mount"

describe Y2Partitioner::Sequences::AddLvmLv do
  using Y2Storage::Refinements::SizeCasts

  # Defined as method instead of let clause because using let, it points to the
  # current devicegraph at the moment to call #current_size for first time, but
  # after a transaction, the current devicegraph could change. The tests need to
  # always access to the current devicegraph, even after a transaction.
  def current_graph
    Y2Partitioner::DeviceGraphs.instance.current
  end

  before do
    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)

    devicegraph_stub("lvm-four-vgs.yml")
  end

  subject(:sequence) { described_class.new(vg) }

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg6") }

  describe "#run" do
    before do
      # Mockup of collected data when go through the dialogs
      allow(sequence).to receive(:controller).and_return(controller)
      controller.lv_name = "lv1"
      controller.size = 1.GiB
    end

    let(:controller) { Y2Partitioner::Sequences::Controllers::LvmLv.new(vg) }

    context "if there is no free space in the vg" do
      before do
        allow(controller).to receive(:free_extents).and_return 0
        allow(Yast::Popup).to receive(:Error)
      end

      it "shows an error popup" do
        expect(Yast::Popup).to receive(:Error)
        sequence.run
      end

      it "quits returning :back" do
        expect(sequence.run).to eq :back
      end

      it "does not create any lv device in the devicegraph" do
        sequence.run
        lvs = Y2Storage::LvmLv.all(current_graph)
        expect(lvs.size).to eq 0
      end
    end

    context "if the user goes forward through all the dialogs" do
      before do
        allow(Y2Partitioner::Dialogs::LvmLvInfo).to receive(:run).and_return :next
        allow(Y2Partitioner::Dialogs::LvmLvSize).to receive(:run).and_return :next
        allow(Y2Partitioner::Dialogs::PartitionRole).to receive(:run).and_return :next
        allow(Y2Partitioner::Dialogs::FormatAndMount).to receive(:run).and_return :next
      end

      it "returns :finish" do
        expect(sequence.run).to eq :finish
      end

      it "creates a new lv device" do
        lvs = Y2Storage::LvmLv.all(current_graph)
        expect(lvs.size).to eq 0

        sequence.run

        lvs = Y2Storage::LvmLv.all(current_graph)
        expect(lvs.size).to eq 1
      end
    end

    context "if the user aborts the process at some point" do
      before do
        allow(Y2Partitioner::Dialogs::LvmLvInfo).to receive(:run).and_return :next
        allow(Y2Partitioner::Dialogs::LvmLvSize).to receive(:run).and_return :next
        allow(Y2Partitioner::Dialogs::PartitionRole).to receive(:run).and_return :next
        allow(Y2Partitioner::Dialogs::FormatAndMount).to receive(:run).and_return :abort
      end

      it "returns :abort" do
        expect(sequence.run).to eq :abort
      end

      it "does not create any lv device in the devicegraph" do
        sequence.run
        lvs = Y2Storage::LvmLv.all(current_graph)
        expect(lvs.size).to eq 0
      end
    end
  end
end
