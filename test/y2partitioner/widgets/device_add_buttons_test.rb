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
require "y2partitioner/widgets/device_add_buttons"

shared_context "action button context" do
  before do
    devicegraph_stub(scenario)

    allow(action).to receive(:new).and_return(instance_double(action, run: action_result))
  end

  subject { described_class.new }

  let(:action_result) { :finish }

  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
end

shared_context "add button context" do
  include_context "action button context"
end

shared_context "device add button context" do
  include_context "action button context"

  subject { described_class.new(device: device) }

  before do
    allow(action).to receive(:new).with(device).and_return(instance_double(action, run: action_result))
  end
end

shared_examples "handle action button" do
  context "if the action returns :finish" do
    let(:action_result) { :finish }

    it "returns :redraw" do
      expect(subject.handle).to eq(:redraw)
    end
  end

  context "if the action does not return :finish" do
    let(:action_result) { nil }

    it "returns nil" do
      expect(subject.handle).to be_nil
    end
  end
end

shared_examples "handle without device" do
  context "when no device is given" do
    let(:device) { nil }

    before do
      allow(Yast2::Popup).to receive(:show)
    end

    it "shows an error message" do
      expect(Yast2::Popup).to receive(:show)

      subject.handle
    end

    it "returns nil" do
      expect(subject.handle).to be_nil
    end
  end
end

shared_examples "add button" do
  let(:scenario) { "one-empty-disk" }

  include_context "add button context"

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "starts the action to create the device" do
      expect(action).to receive(:new)

      subject.handle
    end

    include_examples "handle action button"
  end
end

describe Y2Partitioner::Widgets::MdAddButton do
  let(:action) { Y2Partitioner::Actions::AddMd }

  include_examples "add button"
end

describe Y2Partitioner::Widgets::LvmVgAddButton do
  let(:action) { Y2Partitioner::Actions::AddLvmVg }

  include_examples "add button"
end

describe Y2Partitioner::Widgets::BcacheAddButton do
  let(:action) { Y2Partitioner::Actions::AddBcache }

  include_examples "add button"
end

describe Y2Partitioner::Widgets::BtrfsAddButton do
  let(:action) { Y2Partitioner::Actions::AddBtrfs }

  include_examples "add button"
end

describe Y2Partitioner::Widgets::PartitionAddButton do
  let(:scenario) { "mixed_disks" }

  let(:action) { Y2Partitioner::Actions::AddPartition }

  include_context "device add button context"

  describe "#handle" do
    include_examples "handle without device"

    context "when a disk device is given" do
      let(:device) { devicegraph.find_by_name("/dev/sda") }

      it "starts the action to add a partition over the disk device" do
        expect(action).to receive(:new).with(device).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle action button"
    end

    context "when a partition is given" do
      let(:device) { devicegraph.find_by_name("/dev/sda1") }

      it "starts the action to add a partition over its disk device" do
        expect(action).to receive(:new).with(device.partitionable).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle action button"
    end
  end
end

describe Y2Partitioner::Widgets::LvmLvAddButton do
  let(:scenario) { "lvm-two-vgs" }

  let(:action) { Y2Partitioner::Actions::AddLvmLv }

  include_context "device add button context"

  describe "#handle" do
    include_examples "handle without device"

    context "when a volume group is given" do
      let(:device) { devicegraph.find_by_name("/dev/vg0") }

      it "starts the action to add a logical volume over the volume group" do
        expect(action).to receive(:new).with(device).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle action button"
    end

    context "when a logical volume is given" do
      let(:device) { devicegraph.find_by_name("/dev/vg0/lv1") }

      it "starts the action to add a logical volume over its volume group" do
        expect(action).to receive(:new).with(device.lvm_vg).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle action button"
    end
  end
end

describe Y2Partitioner::Widgets::BtrfsSubvolumeAddButton do
  let(:scenario) { "mixed_disks_btrfs" }

  let(:action) { Y2Partitioner::Actions::AddBtrfsSubvolume }

  include_context "device add button context"

  describe "#handle" do
    include_examples "handle without device"

    context "when a block device is given" do
      let(:device) { devicegraph.find_by_name("/dev/sda2") }

      it "starts the action to add a Btrfs subvolume over its filesystem" do
        expect(action)
          .to receive(:new).with(device.filesystem).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle action button"
    end

    context "when a Btrfs subvolume is given" do
      let(:device) { devicegraph.find_by_name("/dev/sda2").filesystem.btrfs_subvolumes.first }

      it "starts the action to add a Btrfs subvolume over its filesystem" do
        expect(action)
          .to receive(:new).with(device.filesystem).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle action button"
    end

    context "when a filesystem is given" do
      let(:device) { devicegraph.find_by_name("/dev/sda2").filesystem }

      it "starts the action to add a Btrfs subvolume over the filesystem" do
        expect(action).to receive(:new).with(device).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle action button"
    end
  end
end
