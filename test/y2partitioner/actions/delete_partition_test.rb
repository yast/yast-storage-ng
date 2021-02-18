#!/usr/bin/env rspec

# Copyright (c) [2017-2021] SUSE LLC
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
      allow(Yast2::Popup).to receive(:show).and_return(accept)
    end

    let(:accept) { nil }

    shared_examples "do not delete partition" do
      it "does not delete the partition" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    shared_examples "delete partition" do
      it "deletes the partition" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to be_nil
      end

      it "refreshes btrfs subvolumes shadowing" do
        expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
        subject.run
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end
    end

    context "when deleting a partition from an implicit partition table" do
      let(:scenario) { "several-dasds" }

      let(:device_name) { "/dev/dasda1" }

      it "shows an error message" do
        expect(Yast2::Popup).to receive(:show).with(/cannot be deleted/, anything)

        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when deleting a partition from a non-implicit partition table" do
      let(:scenario) { "mixed_disks.yml" }

      let(:device_name) { "/dev/sda2" }

      before do
        allow(Yast2::Popup).to receive(:show).with(/Really delete/, anything).and_return(accept)
      end

      let(:accept) { :no }

      it "shows a confirm message" do
        expect(Yast2::Popup).to receive(:show).with(/Really delete/, anything)

        subject.run
      end

      context "when the confirm message is not accepted" do
        let(:accept) { :no }

        include_examples "do not delete partition"
      end

      context "when the confirm message is accepted" do
        let(:accept) { :yes }

        context "and the partition is not mounted in the system" do
          let(:device_name) { "/dev/sda2" }

          it "does not ask for unmounting the partition" do
            expect_any_instance_of(Y2Partitioner::Dialogs::Unmount).to_not receive(:run)

            subject.run
          end

          include_examples "delete partition"
        end

        context "and the partition is currently mounted in the system" do
          let(:device_name) { "/dev/sdb2" }

          before do
            allow(Y2Partitioner::Dialogs::Unmount).to receive(:new).and_return(unmount_dialog)
          end

          let(:unmount_dialog) { instance_double(Y2Partitioner::Dialogs::Unmount, run: unmount_result) }

          let(:unmount_result) { :cancel }

          it "asks for unmounting the partition" do
            expect(Y2Partitioner::Dialogs::Unmount).to receive(:new) do |devices, _|
              expect(devices).to contain_exactly(an_object_having_attributes(sid: device.filesystem.sid))
            end.and_return(unmount_dialog)

            subject.run
          end

          context "and the user decides to unmount or to continue" do
            let(:unmount_result) { :finish }

            include_examples "delete partition"
          end

          context "and the user decides to cancel" do
            let(:unmount_result) { :cancel }

            include_examples "do not delete partition"
          end
        end
      end
    end

    context "when deleting a partition used by other device" do
      let(:scenario) { "root_partitioned_md_raid.yml" }

      let(:device_name) { "/dev/vda2" }

      before do
        allow(Y2Partitioner::Dialogs::Unmount).to receive(:new).and_return(unmount_dialog)
      end

      let(:unmount_dialog) { instance_double(Y2Partitioner::Dialogs::Unmount, run: :finish) }

      it "ask for deleting all the dependent devices" do
        expect(subject).to receive(:confirm_recursive_delete)
          .with(device, anything, anything, /vda2/)
          .and_call_original

        subject.run
      end

      it "shows a generic confirmation pop-up with a recursive list of devices" do
        expect(Yast::HTML).to receive(:List).with(["/dev/md0", "/dev/md0p1", "/dev/md0p2"])

        subject.run
      end

      it "ask for unmounting all the mounted dependent devices" do
        allow(subject).to receive(:confirm_recursive_delete).and_return(true)

        md0p1_fs = device_graph.find_by_name("/dev/md0p1").filesystem
        md0p2_fs = device_graph.find_by_name("/dev/md0p2").filesystem
        subvols = md0p1_fs.btrfs_subvolumes.reject { |s| s.mount_point.nil? }

        mounted = [md0p1_fs, md0p2_fs] + subvols

        expect(Y2Partitioner::Dialogs::Unmount).to receive(:new) do |devices, _|
          expected = mounted.map { |d| an_object_having_attributes(sid: d.sid) }

          expect(devices).to contain_exactly(*expected)
        end.and_return(unmount_dialog)

        subject.run
      end
    end
  end
end
