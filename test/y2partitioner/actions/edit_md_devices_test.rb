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
require "y2partitioner/actions/edit_md_devices"
require "y2partitioner/dialogs/md_edit_devices"

describe Y2Partitioner::Actions::EditMdDevices do
  before do
    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)
  end

  subject(:action) { described_class.new(md) }

  describe "#run" do
    before do
      devicegraph_stub(scenario)

      allow(Yast2::Popup).to receive(:show)
    end

    let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }

    let(:scenario) { "md_raid" }

    let(:md) { devicegraph.md_raids.first }

    # Regression test
    it "uses the device belonging to the current devicegraph" do
      # Only to finish
      allow(subject).to receive(:run?).and_return(false)

      initial_graph = devicegraph

      expect(Y2Partitioner::Actions::Controllers::Md).to receive(:new) do |params|
        # Modifies used device
        md = params[:md]
        md.remove_descendants

        # Initial device is not modified
        initial_md = initial_graph.find_device(md.sid)
        expect(initial_md.descendants).to_not be_empty
      end

      subject.run
    end

    context "if the MD RAID already exists on the disk" do
      let(:scenario) { "md_raid" }

      let(:md) { devicegraph.md_raids.first }

      it "shows an error" do
        expect(Yast2::Popup).to receive(:show).with(/already created/, anything)

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
        expect(Yast2::Popup).to receive(:show).with(/is in use/, anything)
        action.run
      end

      it "quits returning :back" do
        expect(action.run).to eq :back
      end
    end

    context "if the MD RAID contains partitions" do
      let(:scenario) { "lvm-two-vgs.yml" }

      before do
        md = Y2Storage::Md.create(devicegraph, "/dev/md0")
        pt = md.create_partition_table(Y2Storage::PartitionTables::Type::GPT)
        pt.create_partition("/dev/md0p1", Y2Storage::Region.create(2048, 1048576, 512),
          Y2Storage::PartitionType::PRIMARY)
      end

      let(:md) { devicegraph.find_by_name("/dev/md0") }

      it "shows an error" do
        expect(Yast2::Popup).to receive(:show).with(/is partitioned/, anything)
        action.run
      end

      it "quits returning :back" do
        expect(action.run).to eq :back
      end
    end

    context "if it is possible to edit the devices of the MD RAID" do
      let(:scenario) { "lvm-two-vgs.yml" }

      let(:md) { Y2Storage::Md.create(devicegraph, "/dev/md0") }

      context "and the user goes forward in the dialog" do
        before do
          allow(Y2Partitioner::Dialogs::MdEditDevices).to receive(:run).and_return :next
        end

        it "returns :finish" do
          expect(action.run).to eq(:finish)
        end
      end

      context "and the user aborts the process" do
        before do
          allow(Y2Partitioner::Dialogs::MdEditDevices).to receive(:run).and_return :abort
        end

        it "returns :abort" do
          expect(action.run).to eq :abort
        end
      end
    end
  end
end
