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
  before do
    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)

    devicegraph_stub("lvm-two-vgs.yml")
  end

  let(:vg) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }

  subject(:sequence) { described_class.new(vg) }

  describe "#run" do
    context "if there is no free space in the VG" do
      before do
        allow(Yast::Popup).to receive(:Error)
        vg.create_lvm_lv("filler", vg.available_space)
      end

      it "shows an error" do
        expect(Yast::Popup).to receive(:Error)
        sequence.run
      end

      it "quits returning :back" do
        expect(sequence.run).to eq :back
      end
    end

    context "if there is available space in the VG" do
      pending
    end
  end
end
