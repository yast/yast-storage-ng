#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require_relative "spec_helper"
require "y2storage/simple_etc_fstab_entry"

describe Y2Storage::SimpleEtcFstabEntry do
  before do
    fake_scenario(scenario)
  end

  subject { fstab_entry(device, "/", btrfs, mount_options, 0, 0) }

  let(:device) { "/dev/sda2" }

  let(:btrfs) { Y2Storage::Filesystems::Type::BTRFS }

  let(:mount_options) { [] }

  let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

  let(:scenario) { "mixed_disks" }

  describe "#subvolume?" do
    context "when the entry is for a BTRFS subvolume" do
      let(:mount_options) { ["subvol=@/home"] }

      it "returns true" do
        expect(subject.subvolume?).to eq(true)
      end
    end

    context "when the entry is not for a BTRFS subvolume" do
      let(:mount_options) { ["rw"] }

      it "returns false" do
        expect(subject.subvolume?).to eq(false)
      end
    end
  end

  describe "#filesystem" do
    context "when the filesystem for the entry is found in system" do
      let(:device) { "/dev/sda2" }

      it "returns the filesystem" do
        filesystem = subject.filesystem(devicegraph)

        expect(filesystem).to_not be_nil
        expect(filesystem.blk_devices.first.name).to eq(device)
      end
    end

    context "when the filesystem for the entry is not found in system" do
      let(:device) { "UUID=unknown" }

      it "returns nil" do
        expect(subject.filesystem(devicegraph)).to be_nil
      end
    end
  end

  describe "#device" do
    context "when the filesystem for the entry is found in system" do
      context "and it is a block filesystem" do
        let(:device) { "/dev/sda2" }

        it "returns the device of the filesystem" do
          expect(subject.device(devicegraph).name).to eq("/dev/sda2")
        end
      end

      context "and it is a NFS" do
        let(:scenario) { "nfs1.xml" }

        let(:device) { "srv:/home/a" }

        it "returns the NFS" do
          expect(subject.device(devicegraph).name).to eq("srv:/home/a")
        end
      end
    end

    context "when the filesystem for the entry is not found in system" do
      context "but the device can be found" do
        let(:device) { "/dev/sdc" }

        it "returns the device" do
          expect(subject.device(devicegraph).name).to eq("/dev/sdc")
        end
      end

      context "and the device cannot be found" do
        let(:device) { "/dev/sdc1" }

        it "returns nil" do
          expect(subject.device(devicegraph)).to be_nil
        end
      end
    end
  end
end
