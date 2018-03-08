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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::MountPoint do
  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "mixed_disks_btrfs" }

  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, dev_name) }

  subject(:mount_point) { blk_device.blk_filesystem.mount_point }

  let(:dev_name) { "/dev/sda2" }

  describe "#mount_options=" do
    let(:mount_options) { ["rw", "minorversion=1"] }

    it "sets the given mount options" do
      mount_point.mount_options = mount_options
      expect(mount_point.mount_options).to eq(mount_options)
    end

    it "removes previous mount options" do
      mount_point.mount_options = ["ro"]
      expect(mount_point.mount_options).to include("ro")

      mount_point.mount_options = mount_options
      expect(mount_point.mount_options).to_not include("ro")
    end
  end

  describe "#mount_by" do
    context "for non-btrfs" do
      let(:dev_name) { "/dev/sdb5" } # XFS /home
      subject { blk_device.blk_filesystem.mount_point }

      before do
        subject.mount_by = Y2Storage::Filesystems::MountByType::ID
      end

      it "returns the correct mount_by" do
        expect(subject.mount_by.to_sym).to eq :id
      end
    end

    context "for btrfs" do
      let(:dev_name) { "/dev/sda2" } # Btrfs /, mount_by: label
      let(:btrfs) { blk_device.blk_filesystem }

      it "returns the correct mount_by mode" do
        expect(btrfs.mount_point.mount_by.to_sym).to eq :label
      end

      it "subvolumes inherit the mount_by mode from the parent btrfs" do
        # Don't use the first two subvolumes: They don't have a mount point.
        # One is the toplevel subvolume, one is the default subvolume.
        expect(btrfs.btrfs_subvolumes.last.mount_point.mount_by.to_sym).to eq :label
      end
    end
  end
end
