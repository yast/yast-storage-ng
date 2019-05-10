#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/device_graphs"
require "y2partitioner/actions/edit_btrfs_devices"

describe Y2Partitioner::Actions::EditBtrfsDevices do
  before do
    devicegraph_stub(scenario)

    allow(Yast2::Popup).to receive(:show)

    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)
  end

  subject { described_class.new(filesystem) }

  let(:filesystem) { device.filesystem }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    context "if the filesystem already exists on disk" do
      let(:scenario) { "mixed_disks" }

      let(:device_name) { "/dev/sdb2" }

      it "shows an error" do
        expect(Yast2::Popup).to receive(:show).with(anything, hash_including(headline: :error))

        subject.run
      end

      it "quits returning :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "if the filesystem does not exist on disk" do
      let(:scenario) { "mixed_disks" }

      let(:device_name) { "/dev/sdc" }

      before do
        device.remove_descendants
        device.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
      end

      context "and the user goes forward in the dialog" do
        before do
          allow(Y2Partitioner::Dialogs::BtrfsDevices).to receive(:run).and_return(:next)
        end

        it "returns :finish" do
          expect(subject.run).to eq(:finish)
        end
      end

      context "and the user aborts the process" do
        before do
          allow(Y2Partitioner::Dialogs::BtrfsDevices).to receive(:run).and_return(:abort)
        end

        it "returns :abort" do
          expect(subject.run).to eq(:abort)
        end
      end
    end
  end
end
