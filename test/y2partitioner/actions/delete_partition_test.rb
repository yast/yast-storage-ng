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
      allow(Yast2::Popup).to receive(:show).and_return(accept)
    end

    let(:accept) { nil }

    shared_examples "do not remove partition" do
      it "does not delete the partition" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    shared_examples "confirm" do
      it "shows a confirm message" do
        expect(Yast2::Popup).to receive(:show).with(/Really delete/, anything)
          .and_return(:no)

        subject.run
      end

      context "when the confirm message is not accepted" do
        let(:accept) { :no }

        include_examples "do not remove partition"
      end

      context "when the confirm message is accepted" do
        let(:accept) { :yes }

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

    context "when deleting a partition that is not mounted in the system" do
      let(:scenario) { "mixed_disks.yml" }

      let(:device_name) { "/dev/sda2" }

      it "does not ask for unmounting the partition" do
        expect(Yast2::Popup).to_not receive(:show).with(/try to unmount/, anything)

        subject.run
      end

      include_examples "confirm"
    end

    context "when deleting a partition that is mounted in the system" do
      let(:scenario) { "mixed_disks.yml" }

      let(:device_name) { "/dev/sdb2" }

      before do
        allow(Yast2::Popup).to receive(:show).with(/try to unmount/, anything)
          .and_return(*unmount_answer)
      end

      let(:unmount_answer) { [:cancel] }

      it "asks for unmounting the partition" do
        expect(Yast2::Popup).to receive(:show).with(/try to unmount/, anything)

        subject.run
      end

      it "shows a specific note for deleting" do
        expect(Yast2::Popup).to receive(:show)
          .with(/cannot be deleted while mounted/, anything)
          .and_return(:cancel)

        subject.run
      end

      context "and the user decides to continue" do
        let(:unmount_answer) { [:continue] }

        include_examples "confirm"
      end

      context "and the user decides to cancel" do
        let(:unmount_answer) { [:cancel] }

        include_examples "do not remove partition"
      end

      context "and the user decides to unmount" do
        let(:unmount_answer) { [:unmount, :cancel] }

        context "and the partition can not be unmounted" do
          before do
            allow_any_instance_of(Y2Storage::MountPoint).to receive(:immediate_deactivate)
              .and_raise(Storage::Exception, "fail to unmount")
          end

          it "shows an error message" do
            expect(Yast2::Popup).to receive(:show).with(/could not be unmounted/, anything)

            subject.run
          end

          it "asks for trying to unmount again" do
            expect(Yast2::Popup).to receive(:show).with(/try to unmount/, anything).twice

            subject.run
          end
        end

        context "and the partition can be unmounted" do
          before do
            allow_any_instance_of(Y2Storage::MountPoint).to receive(:immediate_deactivate)
          end

          include_examples "confirm"
        end
      end
    end

    context "when deleting a partition used by LVM" do
      let(:scenario) { "lvm-two-vgs.yml" }

      let(:device_name) { "/dev/sda5" }

      it "shows a specific confirm message for LVM" do
        expect(subject).to receive(:confirm_recursive_delete)
          .with(device, /LVM/, anything, anything)
          .and_call_original

        subject.run
      end
    end

    context "when deleting a partition used by MD Raid" do
      let(:scenario) { "md_raid" }

      let(:device_name) { "/dev/sda1" }

      it "shows a specific confirm message for Md Raid" do
        expect(subject).to receive(:confirm_recursive_delete)
          .with(device, /RAID/, anything, anything)
          .and_call_original

        subject.run
      end
    end
  end
end
