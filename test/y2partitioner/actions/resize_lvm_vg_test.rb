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
# find current contact information at www.suse.com.

require_relative "../test_helper"

require "y2partitioner/actions/resize_lvm_vg"
require "y2partitioner/dialogs/lvm_vg_resize"

describe Y2Partitioner::Actions::ResizeLvmVg do
  before do
    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)

    devicegraph_stub("complex-lvm-encrypt.yml")
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

  subject { described_class.new(vg: vg) }

  describe "#run" do
    context "if the user goes forward through the dialog" do
      before do
        allow(Y2Partitioner::Dialogs::LvmVgResize).to receive(:run).and_return :next
      end

      it "returns :finish" do
        expect(subject.run).to eq :finish
      end
    end

    context "if the user aborts the process" do
      before do
        allow(Y2Partitioner::Dialogs::LvmVgResize).to receive(:run).and_return :abort
      end

      it "returns :abort" do
        expect(subject.run).to eq :abort
      end
    end
  end
end
