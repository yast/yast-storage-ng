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
require "y2partitioner/actions/resize_md"
require "y2partitioner/dialogs/md_resize"

describe Y2Partitioner::Actions::ResizeMd do
  before do
    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)
  end

  subject(:action) { described_class.new(md) }

  describe "#run" do
    before do
      devicegraph_stub(scenario)
    end

    let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }

    context "if the MD RAID already exists on the disk" do
      let(:scenario) { "md_raid.xml" }

      let(:md) { devicegraph.md_raids.first }

      it "shows an error" do
        expect(Yast::Popup).to receive(:Error)
        action.run
      end

      it "quits returning :back" do
        expect(action.run).to eq :back
      end
    end

    context "if the MD RAID is used as LVM physical volume" do
      let(:scenario) { "lvm-two-vgs.yml" }

      before do
        md = Y2Storage::Md.create(devicegraph, "/dev/md0")
        vg = devicegraph.lvm_vgs.first
        vg.add_lvm_pv(md)
      end

      let(:md) { devicegraph.md_raids.first }

      it "shows an error" do
        expect(Yast::Popup).to receive(:Error)
        action.run
      end

      it "quits returning :back" do
        expect(action.run).to eq :back
      end
    end

    context "if the MD RAID is being created and does not belong to a volume group" do
      let(:scenario) { "lvm-two-vgs.yml" }

      let(:md) { Y2Storage::Md.create(devicegraph, "/dev/md0") }

      context "and the user goes forward in the dialog" do
        before do
          allow(Y2Partitioner::Dialogs::MdResize).to receive(:run).and_return :next
        end

        it "returns :finish" do
          expect(action.run).to eq(:finish)
        end
      end

      context "and the user aborts the process" do
        before do
          allow(Y2Partitioner::Dialogs::MdResize).to receive(:run).and_return :abort
        end

        it "returns :abort" do
          expect(action.run).to eq :abort
        end
      end
    end
  end
end
