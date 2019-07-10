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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/actions/delete_partitions"

describe Y2Partitioner::Actions::DeletePartitions do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(device) }

  let(:device) { device_graph.find_by_name(device_name) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show)
    end

    context "when deleting partitions from a directly formatted device" do
      let(:scenario) { "formatted_md" }

      let(:device_name) { "/dev/md0" }

      it "shows an error message" do
        expect(Yast2::Popup).to receive(:show).with(/directly formatted/, anything)

        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when deleting partitions from a device with no partition table" do
      let(:scenario) { "empty_hard_disk_50GiB" }

      let(:device_name) { "/dev/sda" }

      it "shows an error message" do
        expect(Yast2::Popup).to receive(:show)
          .with(/does not contain a partition table/, anything)

        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when deleting partitions from a device with empty partition table" do
      let(:scenario) { "mixed_disks" }

      let(:device_name) { "/dev/sdc" }

      it "shows an error message" do
        expect(Yast2::Popup).to receive(:show)
          .with(/does not contain partitions/, anything)

        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when deleting partitions from a device with partitions" do
      let(:scenario) { "mixed_disks" }

      let(:device_name) { "/dev/sda" }

      before do
        allow(subject).to receive(:confirm_recursive_delete).and_return(accept)
      end

      let(:accept) { nil }

      it "shows a confirm message" do
        expect(subject).to receive(:confirm_recursive_delete)

        subject.run
      end

      context "and the confirm message is not accepted" do
        let(:accept) { false }

        it "does not delete the partitions" do
          subject.run

          expect(device.partitions).to_not be_empty
        end

        it "returns :back" do
          expect(subject.run).to eq(:back)
        end
      end

      context "and the confirm message is accepted" do
        let(:accept) { true }

        it "deletes the partitions" do
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
