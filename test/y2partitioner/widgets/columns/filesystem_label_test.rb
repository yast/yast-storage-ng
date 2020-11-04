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

require_relative "../../test_helper"
require_relative "./shared_examples"

require "y2partitioner/widgets/columns/filesystem_label"

describe Y2Partitioner::Widgets::Columns::FilesystemLabel do

  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "mixed_disks" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, device_name) }
  let(:device_name) { "/dev/sda1" }

  before do
    devicegraph_stub(scenario)
  end

  context "when a there is not a filesystem for given device" do
    let(:scenario) { "btrfs2-devicegraph.xml" }
    let(:device_name) { "/dev/sdb" }

    it "returns an empty string" do
      expect(subject.value_for(device)).to eq("")
    end
  end

  context "when a fstab entry is given" do
    let(:btrfs) { Y2Storage::Filesystems::Type::BTRFS }
    let(:root_fstab_entry) { fstab_entry("/dev/sdb2", "/", btrfs, ["subvol=@/"], 0, 0) }
    let(:unknown_fstab_entry) { fstab_entry("/dev/vdz", "/home", btrfs, [], 0, 0) }

    context "and the device is found in the system" do
      let(:device) { root_fstab_entry }

      it "returns the filesystem label" do
        expect(subject.value_for(device)).to eq("suse_root")
      end
    end

    context "but the device is not found in the system" do
      let(:device) { unknown_fstab_entry }

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end
  end

  context "when the device is part of a multi-device filesystem" do
    let(:scenario) { "btrfs2-devicegraph.xml" }
    let(:device_name) { "/dev/sdb1" }

    it "returns an empty string" do
      expect(subject.value_for(device)).to eq("")
    end
  end

  context "when the device is a Btrfs subvolume" do
    let(:scenario) { "mixed_disks_btrfs" }
    let(:filesystem) { devicegraph.find_by_name("/dev/sda2").filesystem }
    let(:device) { filesystem.btrfs_subvolumes.first }

    it "returns an empty string" do
      expect(subject.value_for(device)).to eq("")
    end
  end

  context "when filesystem responds to #label" do
    let(:device_name) { "/dev/sdb2" }

    it "returns the filesystem label" do
      expect(subject.value_for(device)).to eq("suse_root")
    end
  end

  context "when filesystem does not respond to #label" do
    let(:scenario) { "nfs1.xml" }
    let(:device) do
      Y2Storage::Filesystems::Nfs.find_by_server_and_path(devicegraph, "srv", "/home/a")
    end

    it "returns an empty string" do
      expect(subject.value_for(device)).to eq("")
    end
  end
end
