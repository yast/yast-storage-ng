#!/usr/bin/env rspec

# Copyright (c) [2020-2021] SUSE LLC
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

require "y2partitioner/actions/delete_btrfs_subvolume"

describe Y2Partitioner::Actions::DeleteBtrfsSubvolume do
  before do
    allow(Y2Storage::VolumeSpecification).to receive(:for)
    allow(Y2Storage::VolumeSpecification).to receive(:for).with("/").and_return(root_spec)

    devicegraph_stub(scenario)
  end

  let(:root_spec) { instance_double(Y2Storage::VolumeSpecification, btrfs_default_subvolume: "@") }

  subject { described_class.new(subvolume) }

  let(:filesystem) { device.filesystem }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show).and_return(accept)
    end

    let(:accept) { nil }

    let(:scenario) { "mixed_disks_btrfs" }

    let(:device_name) { "/dev/sda2" }

    let(:subvolume) { filesystem.create_btrfs_subvolume("@/foo", false) }

    shared_examples "do not delete" do
      it "does not delete the Btrfs subvolume" do
        sid = subvolume.sid

        subject.run

        subvolume = current_graph.find_device(sid)
        expect(subvolume).to_not be_nil
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    shared_examples "delete" do
      it "deletes the Btrfs subvolume" do
        sid = subvolume.sid

        subject.run

        subvolume = current_graph.find_device(sid)
        expect(subvolume).to be_nil
      end

      it "refreshes btrfs subvolumes shadowing" do
        expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
        subject.run
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end
    end

    it "shows a confirm message" do
      expect(Yast2::Popup).to receive(:show)

      subject.run
    end

    context "when the confirm message is not accepted" do
      let(:accept) { :no }

      include_examples "do not delete"
    end

    context "when the confirm message is accepted" do
      let(:accept) { :yes }

      context "when the subvolume is not mounted in the system" do
        it "does not ask for unmounting the subvolume" do
          expect_any_instance_of(Y2Partitioner::Dialogs::Unmount).to_not receive(:run)

          subject.run
        end

        include_examples "delete"
      end

      context "when the subvolume is mounted in the system" do
        # All Btrfs subvolumes are mounted in this scenario, no need to mock #active?, just pick any
        # subvolume
        let(:subvolume) { filesystem.btrfs_subvolumes.find { |s| s.path == "@/home" } }

        before do
          allow(Y2Partitioner::Dialogs::Unmount).to receive(:new).and_return(unmount_dialog)
        end

        let(:unmount_dialog) { instance_double(Y2Partitioner::Dialogs::Unmount, run: unmount_result) }

        let(:unmount_result) { :cancel }

        it "asks for unmounting the Btrfs subvolume" do
          expect(Y2Partitioner::Dialogs::Unmount).to receive(:new) do |devices, _|
            expect(devices).to contain_exactly(an_object_having_attributes(sid: subvolume.sid))
          end.and_return(unmount_dialog)

          subject.run
        end

        context "and the user decides to unmount or to continue" do
          let(:unmount_result) { :finish }

          include_examples "delete"
        end

        context "and the user decides to cancel" do
          let(:unmount_result) { :cancel }

          include_examples "do not delete"
        end
      end
    end
  end
end
