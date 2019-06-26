#!/usr/bin/env rspec
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
require "y2partitioner/actions/delete_md"

describe Y2Partitioner::Actions::DeleteMd do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(device) }

  let(:scenario) { "md_raid" }

  let(:device) { Y2Storage::BlkDevice.find_by_name(device_graph, device_name) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show).and_return(accept)
    end

    let(:device_name) { "/dev/md/md0" }

    let(:accept) { nil }

    context "when deleting a regular md raid" do
      it "shows a confirm message" do
        expect(Yast2::Popup).to receive(:show)
        subject.run
      end
    end

    context "when deleting a md raid used by LVM" do
      before do
        # Create a Vg over the md raid
        device.remove_descendants

        vg = Y2Storage::LvmVg.create(device_graph, "vg0")
        vg.add_lvm_pv(device)
        vg.create_lvm_lv("lv1", Y2Storage::DiskSize.GiB(1))
      end

      it "shows a generic confirmation pop-up with a recursive list of devices" do
        expect(subject).to receive(:confirm_recursive_delete)
          .with(device, anything, anything, /md0/)
          .and_call_original

        subject.run
      end
    end

    context "when deleting a partitioned md raid" do
      let(:scenario) { "nested_md_raids" }
      let(:device_name) { "/dev/md0" }

      it "shows a specific confirm message for partitions" do
        expect(subject).to receive(:confirm_recursive_delete)
          .with(device, /Partitions/, anything, anything)
          .and_call_original

        subject.run
      end
    end

    context "when the confirm message is not accepted" do
      let(:accept) { :no }

      it "does not delete the md raid" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when the confirm message is accepted" do
      let(:accept) { :yes }

      it "deletes the md raid" do
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
