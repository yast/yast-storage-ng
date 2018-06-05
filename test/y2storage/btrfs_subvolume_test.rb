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

describe Y2Storage::BtrfsSubvolume do
  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "mixed_disks_btrfs" }

  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }

  let(:dev_name) { "/dev/sda2" }

  let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

  subject(:filesystem) { blk_device.blk_filesystem }

  describe ".shadowing?" do

    context "when a mount point is shadowing another mount point" do
      let(:mount_point) { "/foo" }
      let(:other_mount_point) { "/foo/bar" }

      it "returns true" do
        expect(described_class.shadowing?(mount_point, other_mount_point)).to be(true)
      end
    end

    context "when a mount point is not shadowing another mount point" do
      let(:mount_point) { "/foo" }
      let(:other_mount_point) { "/foobar" }

      it "returns false" do
        expect(described_class.shadowing?(mount_point, other_mount_point)).to be(false)
      end
    end
  end

  describe ".shadowed?" do
    context "when the mount point is not shadowed by other mount points in the system" do
      let(:mount_point) { "/foo" }

      it "returns false" do
        expect(described_class.shadowed?(devicegraph, mount_point)).to be(false)
      end
    end

    context "when the mount point is shadowed by other other mount points in the system" do
      let(:mount_point) { "/home" }

      it "returns true" do
        expect(described_class.shadowed?(devicegraph, mount_point)).to be(true)
      end
    end
  end

  describe ".shadowers" do
    context "when the mount point is not shadowed" do
      let(:mount_point) { "/foo" }

      it "returns an empty list" do
        expect(described_class.shadowers(devicegraph, mount_point)).to be_empty
      end
    end

    context "when the mount point is shadowed by other mount points" do
      let(:mount_point) { "/home" }

      it "returns a list of shadowers" do
        result = described_class.shadowers(devicegraph, mount_point)
        expect(result).to_not be_empty
        expect(result).to all(be_a(Y2Storage::Mountable))
      end
    end
  end

  describe "#shadowed?" do
    subject { filesystem.find_btrfs_subvolume_by_path(subvolume_path) }

    context "when the subvolume is not shadowed" do
      let(:subvolume_path) { "@/tmp" }

      it "returns false" do
        expect(subject.shadowed?).to eq false
      end
    end

    context "when the subvolume is shadowed" do
      let(:subvolume_path) { "@/home" }

      it "returns true" do
        expect(subject.shadowed?).to eq true
      end
    end
  end

  describe "#shadowers" do
    subject { filesystem.find_btrfs_subvolume_by_path(subvolume_path) }

    context "when the subvolume is not shadowed" do
      let(:subvolume_path) { "@/tmp" }

      it "returns an empty list" do
        expect(subject.shadowers).to be_empty
      end
    end

    context "when the subvolume is shadowed" do
      let(:subvolume_path) { "@/home" }

      it "returns a list of shadowers" do
        result = subject.shadowers
        expect(result).to_not be_empty
        expect(result).to all(be_a(Y2Storage::Mountable))
      end

      it "the result does not include the subvolume itself" do
        expect(subject.shadowers.map(&:sid)).to_not include(subject.sid)
      end

      it "the result does not include the subvolume filesystem" do
        expect(subject.shadowers.map(&:sid)).to_not include(filesystem.sid)
      end
    end
  end
end
