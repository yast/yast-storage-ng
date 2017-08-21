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
# find current contact information at www.suse.com.

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::Filesystems::BlkFilesystem do

  before do
    fake_scenario(scenario)
  end
  let(:scenario) { "mixed_disks_btrfs" }
  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, dev_name) }
  subject(:filesystem) { blk_device.blk_filesystem }

  describe "#supports_btrfs_subvolumes?" do
    context "for a Btrfs filesystem" do
      let(:dev_name) { "/dev/sdb2" }

      it "returns true" do
        expect(filesystem.supports_btrfs_subvolumes?).to eq true
      end
    end

    context "for a no-Btrfs filesystem" do
      let(:dev_name) { "/dev/sdb5" }

      it "returns false" do
        expect(filesystem.supports_btrfs_subvolumes?).to eq false
      end
    end
  end

  describe "#in_network?" do
    let(:disk) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, "/dev/sda") }

    context "for a single disk in network" do
      let(:dev_name) { "/dev/sda1" }
      before do
        allow(filesystem).to receive(:ancestors).and_return([disk])
        allow(disk).to receive(:in_network?).and_return(true)
      end

      it "returns true" do
        expect(filesystem.in_network?).to eq true
      end
    end

    context "for a single local disk" do
      before do
        allow(filesystem).to receive(:ancestors).and_return([disk])
        allow(disk).to receive(:in_network?).and_return(false)
      end
      let(:dev_name) { "/dev/sda1" }

      it "returns false" do
        expect(filesystem.in_network?).to eq false
      end
    end

    context "when filesystem has multiple ancestors and none is in network" do
      before do
        allow(filesystem).to receive(:ancestors).and_return([disk, second_disk])
        allow(disk).to receive(:in_network?).and_return(false)
        allow(second_disk).to receive(:in_network?).and_return(false)
      end
      let(:second_disk) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, "/dev/sdb") }
      let(:dev_name) { "/dev/sda1" }

      it "returns false" do
        expect(filesystem.in_network?).to eq false
      end
    end

    context "when filesystem has multiple ancestors and at least one disk is in network" do
      before do
        allow(filesystem).to receive(:ancestors).and_return([disk, second_disk])
        allow(disk).to receive(:in_network?).and_return(false)
        allow(second_disk).to receive(:in_network?).and_return(true)
      end
      let(:second_disk) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, "/dev/sdb") }
      let(:dev_name) { "/dev/sda1" }

      it "returns true" do
        expect(filesystem.in_network?).to eq true
      end
    end
  end
end
