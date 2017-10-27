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
require "y2partitioner/widgets/delete_disk_partition_button"

describe Y2Partitioner::Actions::DeleteBlkDevice do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:device) { Y2Storage::BlkDevice.find_by_name(device_graph, device_name) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(device) }

  describe "#run" do
    let(:device_name) { "/dev/sda2" }

    before do
      allow(Yast::Popup).to receive(:YesNo).and_return(accept)
    end

    let(:accept) { nil }

    it "shows a confirm message" do
      expect(Yast::Popup).to receive(:YesNo)
      subject.run
    end

    context "when the confirm message is not accepted" do
      let(:accept) { false }

      it "does not delete the device" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when the confirm message is accepted" do
      let(:accept) { true }

      it "refresh btrfs subvolumes shadowing" do
        expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
        subject.run
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end

      context "and the device is a partition" do
        let(:device_name) { "/dev/sda2" }

        it "deletes the partition" do
          subject.run
          expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to be_nil
        end
      end

      context "and the device is not a partition" do
        let(:device_name) { "/dev/sda" }

        before do
          allow(Yast::UI).to receive(:UserInput).and_return(:yes)
        end

        it "deletes all its partitions" do
          expect(device.partitions).to_not be_empty
          subject.run
          expect(device.partitions).to be_empty
        end
      end
    end

    context "when the device is a disk device" do
      context "and does not have partitions" do
        let(:device_name) { "/dev/sdc" }

        it "shows an error message" do
          expect(Yast::Popup).to receive(:Error)
          subject.run
        end

        it "does not delete the device" do
          subject.run
          expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
        end

        it "returns :back" do
          expect(subject.run).to eq(:back)
        end
      end
    end
  end
end
