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
require_relative "button_context"
require_relative "button_examples"

require "y2partitioner/widgets/btrfs_buttons"

describe Y2Partitioner::Widgets::BtrfsAddButton do
  let(:action) { Y2Partitioner::Actions::AddBtrfs }

  let(:scenario) { "one-empty-disk" }

  include_examples "add button"
end

describe Y2Partitioner::Widgets::BtrfsEditButton do
  let(:action) { Y2Partitioner::Actions::EditBtrfs }

  let(:scenario) { "mixed_disks_btrfs" }

  let(:device) { devicegraph.find_by_name("/dev/sda2").filesystem }

  include_examples "button"
end

describe Y2Partitioner::Widgets::BtrfsDeleteButton do
  let(:action) { Y2Partitioner::Actions::DeleteBtrfs }

  let(:scenario) { "mixed_disks_btrfs" }

  let(:device) { devicegraph.find_by_name("/dev/sda2").filesystem }

  include_examples "button"
end

describe Y2Partitioner::Widgets::BtrfsDevicesEditButton do
  let(:action) { Y2Partitioner::Actions::EditBtrfsDevices }

  let(:scenario) { "mixed_disks_btrfs" }

  let(:device) { devicegraph.find_by_name("/dev/sda2").filesystem }

  include_examples "button"
end

describe Y2Partitioner::Widgets::BtrfsSubvolumeAddButton do
  let(:scenario) { "mixed_disks_btrfs" }

  let(:action) { Y2Partitioner::Actions::AddBtrfsSubvolume }

  include_context "device button context"

  describe "#handle" do
    include_examples "handle without device"

    context "when a block device is given" do
      let(:device) { devicegraph.find_by_name("/dev/sda2") }

      it "starts the action to add a Btrfs subvolume over its filesystem" do
        expect(action)
          .to receive(:new).with(device.filesystem).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle result"
    end

    context "when a Btrfs subvolume is given" do
      let(:device) { devicegraph.find_by_name("/dev/sda2").filesystem.btrfs_subvolumes.first }

      it "starts the action to add a Btrfs subvolume over its filesystem" do
        expect(action)
          .to receive(:new).with(device.filesystem).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle result"
    end

    context "when a filesystem is given" do
      let(:device) { devicegraph.find_by_name("/dev/sda2").filesystem }

      it "starts the action to add a Btrfs subvolume over the filesystem" do
        expect(action).to receive(:new).with(device).and_return(double("action", run: nil))

        subject.handle
      end

      include_examples "handle result"
    end
  end
end

describe Y2Partitioner::Widgets::BtrfsSubvolumeEditButton do
  let(:action) { Y2Partitioner::Actions::EditBtrfsSubvolume }

  let(:scenario) { "mixed_disks_btrfs" }

  let(:device) { devicegraph.find_by_name("/dev/sda2").filesystem.btrfs_subvolumes.first }

  include_examples "button"
end

describe Y2Partitioner::Widgets::BtrfsSubvolumeDeleteButton do
  let(:action) { Y2Partitioner::Actions::DeleteBtrfsSubvolume }

  let(:scenario) { "mixed_disks_btrfs" }

  let(:device) { devicegraph.find_by_name("/dev/sda2").filesystem.btrfs_subvolumes.first }

  include_examples "button"
end
