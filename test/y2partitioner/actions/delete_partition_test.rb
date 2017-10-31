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
require "y2partitioner/actions/delete_partition"

describe Y2Partitioner::Actions::DeletePartition do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(device) }

  let(:device) { Y2Storage::BlkDevice.find_by_name(device_graph, device_name) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Yast::Popup).to receive(:YesNo).and_return(accept)
    end

    let(:scenario) { "lvm-two-vgs.yml" }

    let(:device_name) { "/dev/sda2" }

    let(:accept) { nil }

    context "when deleting a plain partition" do
      let(:device_name) { "/dev/sda2" }

      it "shows a confirm message" do
        expect(Yast::Popup).to receive(:YesNo)
        subject.run
      end
    end

    context "when deleting a partition used by LVM" do
      let(:device_name) { "/dev/sda5" }

      it "shows a specific confirm message for LVM" do
        devices = ["/dev/vg1", "/dev/vg1/lv1"]

        expect(subject).to receive(:confirm_recursive_delete)
          .with(array_including(*devices), /LVM/, anything, anything)
          .and_call_original

        subject.run
      end
    end

    context "when deleting a partition used by MD Raid" do
      let(:scenario) { "md_raid.xml" }

      let(:device_name) { "/dev/sda1" }

      it "shows a specific confirm message for Md Raid" do
        devices = ["/dev/md/md0"]

        expect(subject).to receive(:confirm_recursive_delete)
          .with(array_including(*devices), /RAID/, anything, anything)
          .and_call_original

        subject.run
      end
    end

    context "when the confirm message is not accepted" do
      let(:accept) { false }

      it "does not delete the partition" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when the confirm message is accepted" do
      let(:accept) { true }

      it "deletes the partition" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to be_nil
      end

      it "refresh btrfs subvolumes shadowing" do
        expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
        subject.run
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end
    end
  end
end
