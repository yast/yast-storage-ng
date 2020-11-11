#!/usr/bin/env rspec
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
  using Y2Storage::Refinements::SizeCasts

  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "mixed_disks_btrfs" }

  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }

  let(:dev_name) { "/dev/sda2" }

  let(:subvolume_path) { "@/home" }

  let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

  let(:filesystem) { blk_device.blk_filesystem }

  subject(:subvolume) { filesystem.find_btrfs_subvolume_by_path(subvolume_path) }

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

  describe "#referenced" do
    context "if quotas are not enabled for the Btrfs filesystem" do
      it "returns nil" do
        expect(subvolume.referenced).to be_nil
      end
    end

    context "if quotas are enabled for the filesystem" do
      let(:scenario) { "btrfs_simple_quotas.xml" }
      let(:dev_name) { "/dev/vda2" }

      context "and the subvolume has an associated level 0 qgroup" do
        let(:subvolume_path) { "@/home" }

        it "returns the size of the referenced space" do
          expect(subvolume.referenced).to eq 48.KiB
        end
      end

      context "and the subvolume does not have an associated qgroup" do
        let(:subvolume_path) { "@/opt" }

        it "returns nil" do
          expect(subvolume.referenced).to be_nil
        end
      end
    end
  end

  describe "#exclusive" do
    context "if quotas are not enabled for the Btrfs filesystem" do
      it "returns nil" do
        expect(subvolume.exclusive).to be_nil
      end
    end

    context "if quotas are enabled for the filesystem" do
      let(:scenario) { "btrfs_simple_quotas.xml" }
      let(:dev_name) { "/dev/vda2" }

      context "and the subvolume has an associated level 0 qgroup" do
        let(:subvolume_path) { "@/home" }

        it "returns the size of the exclusive space" do
          expect(subvolume.exclusive).to eq 48.KiB
        end
      end

      context "and the subvolume does not have an associated qgroup" do
        let(:subvolume_path) { "@/opt" }

        it "returns nil" do
          expect(subvolume.exclusive).to be_nil
        end
      end
    end
  end

  describe "#referenced_limit" do
    context "if quotas are not enabled for the Btrfs filesystem" do
      it "returns unlimited" do
        expect(subvolume.referenced_limit).to be_unlimited
      end
    end

    context "if quotas are enabled for the filesystem" do
      let(:scenario) { "btrfs_simple_quotas.xml" }
      let(:dev_name) { "/dev/vda2" }

      context "and the subvolume has an associated qgroup with a referenced limit" do
        let(:subvolume_path) { "@/var" }

        it "returns the size of the referenced limit" do
          expect(subvolume.referenced_limit).to eq 10.GiB
        end
      end

      context "and the subvolume has an associated qgroup with no referenced limit" do
        let(:subvolume_path) { "@/root" }

        it "returns unlimited" do
          expect(subvolume.referenced_limit).to be_unlimited
        end
      end

      context "and the subvolume does not have an associated qgroup" do
        let(:subvolume_path) { "@/opt" }

        it "returns unlimited" do
          expect(subvolume.referenced_limit).to be_unlimited
        end
      end
    end
  end

  describe "#referenced_limit=" do
    context "if quotas are not enabled for the Btrfs filesystem" do
      it "has no effect" do
        expect(subvolume.referenced_limit).to be_unlimited
        subvolume.referenced_limit = 330.MiB
        expect(subvolume.referenced_limit).to be_unlimited
        subvolume.referenced_limit = Y2Storage::DiskSize.unlimited
        expect(subvolume.referenced_limit).to be_unlimited
      end
    end

    context "if quotas are enabled for the filesystem" do
      let(:scenario) { "btrfs_simple_quotas.xml" }
      let(:dev_name) { "/dev/vda2" }

      context "and the subvolume has an associated qgroup with a referenced limit" do
        let(:subvolume_path) { "@/var" }

        it "changes the limit if a size is given" do
          subvolume.referenced_limit = 350.MiB
          expect(subvolume.referenced_limit).to eq 350.MiB
        end

        it "removes the limit if unlimited is given" do
          subvolume.referenced_limit = Y2Storage::DiskSize.unlimited
          expect(subvolume.referenced_limit).to be_unlimited
        end
      end

      context "and the subvolume has an associated qgroup with no referenced limit" do
        let(:subvolume_path) { "@/root" }

        it "sets a new limit if a size is given" do
          expect(subvolume.referenced_limit).to be_unlimited
          subvolume.referenced_limit = 400.MiB
          expect(subvolume.referenced_limit).to eq 400.MiB
        end

        it "does not set any limit if unlimited is given" do
          subvolume.referenced_limit = Y2Storage::DiskSize.unlimited
          expect(subvolume.referenced_limit).to be_unlimited
        end
      end

      context "and the subvolume does not have an associated qgroup" do
        let(:subvolume_path) { "@/opt" }

        it "sets a new limit if a size is given" do
          expect(subvolume.referenced_limit).to be_unlimited
          subvolume.referenced_limit = 400.MiB
          expect(subvolume.referenced_limit).to eq 400.MiB
        end

        it "does not set any limit if unlimited is given" do
          subvolume.referenced_limit = Y2Storage::DiskSize.unlimited
          expect(subvolume.referenced_limit).to be_unlimited
        end
      end
    end
  end

  describe "#exclusive_limit" do
    context "if quotas are not enabled for the Btrfs filesystem" do
      it "returns unlimited" do
        expect(subvolume.exclusive_limit).to be_unlimited
      end
    end

    context "if quotas are enabled for the filesystem" do
      let(:scenario) { "btrfs_simple_quotas.xml" }
      let(:dev_name) { "/dev/vda2" }

      context "and the subvolume has an associated qgroup with a exclusive limit" do
        let(:subvolume_path) { "@/srv" }

        it "returns the size of the exclusive limit" do
          expect(subvolume.exclusive_limit).to eq 2.5.GiB
        end
      end

      context "and the subvolume has an associated qgroup with no exclusive limit" do
        let(:subvolume_path) { "@/var" }

        it "returns unlimited" do
          expect(subvolume.exclusive_limit).to be_unlimited
        end
      end

      context "and the subvolume does not have an associated qgroup" do
        let(:subvolume_path) { "@/opt" }

        it "returns unlimited" do
          expect(subvolume.exclusive_limit).to be_unlimited
        end
      end
    end
  end

  describe "#exclusive_limit=" do
    context "if quotas are not enabled for the Btrfs filesystem" do
      it "has no effect" do
        expect(subvolume.exclusive_limit).to be_unlimited
        subvolume.exclusive_limit = 330.MiB
        expect(subvolume.exclusive_limit).to be_unlimited
        subvolume.exclusive_limit = Y2Storage::DiskSize.unlimited
        expect(subvolume.exclusive_limit).to be_unlimited
      end
    end

    context "if quotas are enabled for the filesystem" do
      let(:scenario) { "btrfs_simple_quotas.xml" }
      let(:dev_name) { "/dev/vda2" }

      context "and the subvolume has an associated qgroup with a exclusive limit" do
        let(:subvolume_path) { "@/srv" }

        it "changes the limit if a size is given" do
          subvolume.exclusive_limit = 350.MiB
          expect(subvolume.exclusive_limit).to eq 350.MiB
        end

        it "removes the limit if unlimited is given" do
          subvolume.exclusive_limit = Y2Storage::DiskSize.unlimited
          expect(subvolume.exclusive_limit).to be_unlimited
        end
      end

      context "and the subvolume has an associated qgroup with no exclusive limit" do
        let(:subvolume_path) { "@/var" }

        it "sets a new limit if a size is given" do
          expect(subvolume.exclusive_limit).to be_unlimited
          subvolume.exclusive_limit = 400.MiB
          expect(subvolume.exclusive_limit).to eq 400.MiB
        end

        it "does not set any limit if unlimited is given" do
          subvolume.exclusive_limit = Y2Storage::DiskSize.unlimited
          expect(subvolume.exclusive_limit).to be_unlimited
        end
      end

      context "and the subvolume does not have an associated qgroup" do
        let(:subvolume_path) { "@/opt" }

        it "sets a new limit if a size is given" do
          expect(subvolume.exclusive_limit).to be_unlimited
          subvolume.exclusive_limit = 400.MiB
          expect(subvolume.exclusive_limit).to eq 400.MiB
        end

        it "does not set any limit if unlimited is given" do
          subvolume.exclusive_limit = Y2Storage::DiskSize.unlimited
          expect(subvolume.exclusive_limit).to be_unlimited
        end
      end
    end
  end
end
