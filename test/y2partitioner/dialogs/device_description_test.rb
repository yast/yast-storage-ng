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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/dialogs/device_description"

describe Y2Partitioner::Dialogs::DeviceDescription do
  before do
    devicegraph_stub(scenario)
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:scenario) { "md_raid_lvm" }
  let(:device) { current_graph.disks.first }

  subject { described_class.new(device) }

  include_examples "CWM::Dialog"

  context "for an unsupported type of device" do
    let(:device) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/mapper/cr_md0") }

    describe "#run" do
      it "does not open the pop-up and returns nil" do
        expect(subject.run).to eq nil
      end
    end
  end

  context "for a hard disk" do
    let(:device) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/vda") }

    describe "#title" do
      it "includes the name of the disk" do
        expect(subject.title).to include device.name
      end
    end

    describe "#contents" do
      it "includes a widget with the description of the disk" do
        expect(Y2Partitioner::Widgets::DiskDeviceDescription).to receive(:new).with(device)
        subject.contents
      end
    end

    describe "#run" do
      it "opens the pop-up and returns the result of the user input" do
        expect_any_instance_of(Y2Partitioner::Dialogs::Popup).to receive(:run).and_return(:ok)
        expect(subject.run).to eq :ok
      end
    end
  end

  context "for Btrfs filesystem" do
    let(:scenario) { "mixed_disks_btrfs" }
    let(:device) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/sda2").filesystem }

    describe "#title" do
      it "includes the base name of the corresponding block device" do
        expect(subject.title).to include "sda2"
      end
    end

    describe "#contents" do
      it "includes a widget with the description of the Btrfs" do
        expect(Y2Partitioner::Widgets::FilesystemDescription).to receive(:new).with(device)
        subject.contents
      end
    end

    describe "#run" do
      it "opens the pop-up and returns the result of the user input" do
        expect_any_instance_of(Y2Partitioner::Dialogs::Popup).to receive(:run).and_return(:ok)
        expect(subject.run).to eq :ok
      end
    end
  end

  context "for a XEN partition" do
    let(:scenario) { "xen-partitions.xml" }
    let(:device) { current_graph.find_by_name("/dev/xvda1") }

    describe "#title" do
      it "includes the name of the device" do
        expect(subject.title).to include device.name
      end
    end

    describe "#contents" do
      it "includes a widget with the description of the device" do
        expect(Y2Partitioner::Widgets::StrayBlkDeviceDescription).to receive(:new).with(device)
        subject.contents
      end
    end

    describe "#run" do
      it "opens the pop-up and returns the result of the user input" do
        expect_any_instance_of(Y2Partitioner::Dialogs::Popup).to receive(:run).and_return(:ok)
        expect(subject.run).to eq :ok
      end
    end
  end
end
