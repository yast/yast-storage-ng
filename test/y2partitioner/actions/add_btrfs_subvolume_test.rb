#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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

require "y2partitioner/actions/add_btrfs_subvolume"

describe Y2Partitioner::Actions::AddBtrfsSubvolume do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(filesystem) }

  let(:filesystem) { device.filesystem }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Y2Partitioner::Dialogs::BtrfsSubvolume).to receive(:new).and_return(dialog)

      allow(Y2Partitioner::Actions::Controllers::BtrfsSubvolume).to receive(:new).and_return(controller)
    end

    let(:scenario) { "mixed_disks_btrfs" }

    let(:device_name) { "/dev/sda2" }

    let(:dialog) { instance_double(Y2Partitioner::Dialogs::BtrfsSubvolume, run: result) }

    let(:controller) { Y2Partitioner::Actions::Controllers::BtrfsSubvolume.new(filesystem) }

    let(:result) { nil }

    it "opens a dialog to create a Btrfs subvolume" do
      expect(Y2Partitioner::Dialogs::BtrfsSubvolume).to receive(:new)

      subject.run
    end

    context "when the dialog is accepted" do
      let(:result) { :next }

      before do
        controller.subvolume_path = "@/foo"
        controller.subvolume_nocow = true
      end

      it "creates a new Btrfs subvolume with the given attributes" do
        subvolume = filesystem.btrfs_subvolumes.find { |s| s.path == "@/foo" }
        expect(subvolume).to be_nil

        subject.run

        subvolume = filesystem.btrfs_subvolumes.find { |s| s.path == "@/foo" }
        expect(subvolume).to_not be_nil
        expect(subvolume.nocow?).to eq(true)
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end
    end

    context "when the dialog is discarded" do
      let(:result) { :back }

      it "does not create a new Btrfs subvolume" do
        subvolumes = filesystem.btrfs_subvolumes

        subject.run

        expect(filesystem.btrfs_subvolumes).to eq(subvolumes)
      end

      it "returns nil" do
        expect(subject.run).to be_nil
      end
    end
  end
end
