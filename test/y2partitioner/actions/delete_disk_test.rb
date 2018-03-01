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
require "y2partitioner/actions/delete_disk"

describe Y2Partitioner::Actions::DeleteDisk do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:device) { Y2Storage::BlkDevice.find_by_name(device_graph, device_name) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(device) }

  describe "#run" do
    before do
      # allow(Yast::Popup).to receive(:YesNo).and_return(accept)
      allow(Yast::UI).to receive(:UserInput).and_return(accept)
    end

    let(:device_name) { "/dev/sda" }

    let(:accept) { :yes }

    context "when the device does not have partitions" do
      let(:device_name) { "/dev/sdc" }

      it "shows an error message" do
        expect(Yast::Popup).to receive(:Error)
        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when the device has partitions" do
      let(:device_name) { "/dev/sda" }

      it "shows a confirm message" do
        expect(subject).to receive(:confirm_recursive_delete)
          .with(device, anything, anything, anything)
          .and_call_original

        subject.run
      end

      context "and the confirm message is not accepted" do
        let(:accept) { :no }

        it "does not delete the disk partitions" do
          previous_partitions = device.partitions
          subject.run
          expect(device.partitions).to eq(previous_partitions)
        end

        it "returns :back" do
          expect(subject.run).to eq(:back)
        end
      end

      context "when the confirm message is accepted" do
        let(:accept) { :yes }

        it "deletes all its partitions" do
          expect(device.partitions).to_not be_empty
          subject.run
          expect(device.partitions).to be_empty
        end

        it "refreshes btrfs subvolumes shadowing" do
          expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
          subject.run
        end

        it "returns :finish" do
          expect(subject.run).to eq(:finish)
        end
      end
    end
  end
end
