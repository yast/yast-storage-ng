#!/usr/bin/env rspec

# Copyright (c) [2021] SUSE LLC
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
require "y2partitioner/dialogs/unmount"

describe Y2Partitioner::Dialogs::Unmount do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(devices, note:, allow_continue:) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks_btrfs.yml" }

  let(:devices) { [device1, device2] }

  let(:device1) { device_graph.find_by_name("/dev/sdb1").filesystem }

  let(:device2) do
    device_graph.find_by_name("/dev/sda2").filesystem.btrfs_subvolumes.find { |s| s.path == "@/home" }
  end

  let(:note) { nil }

  let(:allow_continue) { true }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show).with(/try to unmount/, anything)
        .and_return(*unmount_answer)

      allow_any_instance_of(Y2Storage::MountPoint).to receive(:immediate_deactivate)
    end

    let(:unmount_answer) { [:cancel] }

    it "asks for unmounting the given devices" do
      expect(Yast2::Popup).to receive(:show) do |text, _|
        expect(text).to match(/try to unmount/)
        expect(text).to match(/sdb1 mounted at swap/)
        expect(text).to match(/Btrfs subvolume @\/home mounted at \/home/)
      end

      subject.run
    end

    context "when a note is given" do
      let(:note) { "This note is included in the dialog" }

      it "includes the given note" do
        expect(Yast2::Popup).to receive(:show).with(/#{note}/, anything)

        subject.run
      end
    end

    context "when continue without unmounting is allowed" do
      let(:allow_continue) { true }

      it "shows a continue button" do
        expect(Yast2::Popup).to receive(:show) do |_, options|
          expect(options[:buttons][:continue]).to_not be_nil
        end

        subject.run
      end
    end

    context "when continue without unmounting is not allowed" do
      let(:allow_continue) { false }

      it "does not show a continue button" do
        expect(Yast2::Popup).to receive(:show) do |_, options|
          expect(options[:buttons][:continue]).to be_nil
        end

        subject.run
      end
    end

    context "when the user decides to continue without unmounting" do
      let(:unmount_answer) { [:continue] }

      it "does not try to unmount the given devices" do
        expect(Y2Partitioner::Unmounter).to_not receive(:new)

        subject.run
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end
    end

    context "when the user decides to cancel" do
      let(:unmount_answer) { [:cancel] }

      it "does not try to unmount the given devices" do
        expect(Y2Partitioner::Unmounter).to_not receive(:new)

        subject.run
      end

      it "returns :cancel" do
        expect(subject.run).to eq(:cancel)
      end
    end

    context "when the user decides to unmount" do
      let(:unmount_answer) { [:unmount, :cancel] }

      before do
        allow(Y2Partitioner::Unmounter).to receive(:new).with(device1).and_return(unmounter1)
        allow(Y2Partitioner::Unmounter).to receive(:new).with(device2).and_return(unmounter2)
      end

      let(:unmounter1) do
        instance_double(Y2Partitioner::Unmounter, unmount: nil, error?: error1, error: e1_details)
      end

      let(:unmounter2) do
        instance_double(Y2Partitioner::Unmounter, unmount: nil, error?: error2, error: e2_details)
      end

      let(:error1) { false }
      let(:e1_details) { nil }

      let(:error2) { false }
      let(:e2_details) { nil }

      it "tries to unmount all the given devices" do
        expect(unmounter1).to receive(:unmount)
        expect(unmounter2).to receive(:unmount)

        subject.run
      end

      context "and all the devices were correctly unmounted" do
        let(:error1) { false }

        let(:error2) { false }

        it "returns :finish" do
          expect(subject.run).to eq(:finish)
        end
      end

      context "and some devices cannot be unmounted" do
        let(:error1) { false }

        let(:error2) { true }

        let(:e2_details) { "failed to unmount sdb5" }

        it "informs about the failed unmounts" do
          expect(Yast2::Popup).to receive(:show).and_return(:unmount)

          expect(Yast2::Popup).to receive(:show) do |text, _|
            expect(text).to match(/cannot be unmounted/)
            expect(text).to match(/@\/home mounted at \/home/)

            expect(text).to_not match(/sdb1/)
          end

          expect(Yast2::Popup).to receive(:show).and_return(:cancel)

          subject.run
        end

        it "asks for trying to unmount again" do
          expect(Yast2::Popup).to receive(:show).with(/try to unmount/, anything).and_return(:unmount)
          expect(Yast2::Popup).to receive(:show)
          expect(Yast2::Popup).to receive(:show).with(/try to unmount/, anything).and_return(:cancel)

          subject.run
        end

        it "does not include the correctly unmounted devices" do
          expect(Yast2::Popup).to receive(:show).with(/try to unmount/, anything).and_return(:unmount)

          expect(Yast2::Popup).to receive(:show)

          expect(Yast2::Popup).to receive(:show) do |text, _|
            expect(text).to match(/try to unmount/)
            expect(text).to_not match(/sdb1 mounted at swap/)
          end.and_return(:cancel)

          subject.run
        end
      end
    end
  end
end
