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

describe Y2Storage::Filesystems::Btrfs do
  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "mixed_disks_btrfs" }

  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }

  let(:dev_name) { "/dev/sda2" }

  subject(:filesystem) { blk_device.blk_filesystem }

  let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

  describe "#btrfs_subvolumes" do
    it "returns an array of BtrfsSubvolume objects" do
      expect(filesystem.btrfs_subvolumes).to be_a Array
      expect(filesystem.btrfs_subvolumes).to all(be_a(Y2Storage::BtrfsSubvolume))
    end
  end

  describe "#top_level_btrfs_subvolume" do
    it "returns a subvolume with 5 as id" do
      expect(filesystem.top_level_btrfs_subvolume).to be_a Y2Storage::BtrfsSubvolume
      expect(filesystem.top_level_btrfs_subvolume.id).to eq 5

    end
  end

  describe "#default_btrfs_subvolume" do
    it "returns a BtrfsSubvolume object" do
      expect(filesystem.default_btrfs_subvolume).to be_a(Y2Storage::BtrfsSubvolume)
    end

    it "returns the default subvolume" do
      expect(filesystem.default_btrfs_subvolume.path).to eq("@")
    end
  end

  describe "#find_btrfs_subvolume_by_path" do
    context "when exists a subvolume with the searched path" do
      it "returns the subvolume with that path" do
        path = "@/home"
        subvolume = filesystem.find_btrfs_subvolume_by_path(path)

        expect(subvolume).to be_a(Y2Storage::BtrfsSubvolume)
        expect(subvolume.path).to eq(path)
      end
    end

    context "when does not exist a subvolume with the searched path" do
      it "returns nil" do
        expect(filesystem.find_btrfs_subvolume_by_path("@/foo")).to be_nil
      end
    end
  end

  describe "#ensure_default_btrfs_subvolume" do
    let(:sda2) { "/dev/sda2" } # default is @
    let(:sdb2) { "/dev/sdb2" } # default is top level

    context "when the requested default path is nil" do
      let(:dev_name) { sda2 }
      let(:path) { nil }

      it "does not create a new subvolume" do
        subvolumes = filesystem.btrfs_subvolumes
        filesystem.ensure_default_btrfs_subvolume(path: path)

        expect(filesystem.btrfs_subvolumes.map(&:path) - subvolumes.map(&:path)).to be_empty
      end

      it "returns the current default subvolume" do
        default = filesystem.default_btrfs_subvolume
        subvolume = filesystem.ensure_default_btrfs_subvolume(path: path)

        expect(subvolume).to eq(default)
      end
    end

    context "when the requested default path is the top level subvolume path" do
      let(:dev_name) { sda2 }
      let(:path) { filesystem.top_level_btrfs_subvolume.path }

      it "does not create a new subvolume" do
        subvolumes = filesystem.btrfs_subvolumes
        filesystem.ensure_default_btrfs_subvolume(path: path)

        expect(filesystem.btrfs_subvolumes.map(&:path) - subvolumes.map(&:path)).to be_empty
      end

      it "returns the top level subvolume" do
        subvolume = filesystem.ensure_default_btrfs_subvolume(path: path)
        expect(subvolume.top_level?).to be(true)
      end

      it "sets the top level subvolume as default subvolume" do
        expect(filesystem.top_level_btrfs_subvolume.default_btrfs_subvolume?).to eq(false)

        filesystem.ensure_default_btrfs_subvolume(path: path)

        expect(filesystem.top_level_btrfs_subvolume.default_btrfs_subvolume?).to eq(true)
      end
    end

    context "when the requested default path does not exist" do
      let(:dev_name) { "/dev/sdb3" }
      let(:path) { "@" }

      it "creates a new default subvolume with the requested path" do
        expect(filesystem.btrfs_subvolumes.map(&:path)).to_not include(path)

        subvolume = filesystem.ensure_default_btrfs_subvolume(path: path)

        expect(subvolume.default_btrfs_subvolume?).to be(true)
        expect(subvolume.path).to eq(path)
      end
    end

    context "when the requested default path already exists" do
      let(:dev_name) { sda2 }
      let(:path) { "@/home" }

      it "does not create a new subvolume" do
        subvolumes = filesystem.btrfs_subvolumes
        filesystem.ensure_default_btrfs_subvolume(path: path)

        expect(filesystem.btrfs_subvolumes.map(&:path) - subvolumes.map(&:path)).to be_empty
      end

      it "returns the subvolume with the requested path" do
        subvolume = filesystem.ensure_default_btrfs_subvolume(path: path)
        expect(subvolume.path).to eq(path)
      end

      it "sets the subvolume as default subvolume" do
        expect(filesystem.find_btrfs_subvolume_by_path(path).default_btrfs_subvolume?).to eq(false)

        filesystem.ensure_default_btrfs_subvolume(path: path)

        expect(filesystem.find_btrfs_subvolume_by_path(path).default_btrfs_subvolume?).to eq(true)
      end
    end
  end

  describe "#delete_btrfs_subvolume" do
    context "when the filesystem has a subvolume with the indicated path" do
      let(:path) { "@/home" }

      it "deletes the subvolume" do
        expect(filesystem.btrfs_subvolumes.map(&:path)).to include(path)
        filesystem.delete_btrfs_subvolume(devicegraph, path)
        expect(filesystem.btrfs_subvolumes.map(&:path)).to_not include(path)
      end
    end

    context "when the filesystem has not a subvolume with the indicated path" do
      let(:path) { "@/foo" }

      it "does not delete any subvolume" do
        subvolumes_before = filesystem.btrfs_subvolumes
        filesystem.delete_btrfs_subvolume(devicegraph, path)
        expect(filesystem.btrfs_subvolumes).to eq(subvolumes_before)
      end
    end
  end

  describe "#create_btrfs_subvolume" do
    let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    let(:path) { "@/foo" }
    let(:nocow) { true }

    it "creates a new subvolume" do
      expect(filesystem.btrfs_subvolumes.map(&:path)).to_not include(path)
      filesystem.create_btrfs_subvolume(path, nocow)
      expect(filesystem.btrfs_subvolumes.map(&:path)).to include(path)
    end

    it "returns the new created subvolume" do
      subvolume = filesystem.create_btrfs_subvolume(path, nocow)
      expect(subvolume).to be_a(Y2Storage::BtrfsSubvolume)
      expect(subvolume.path).to eq(path)
      expect(subvolume.nocow?).to eq(nocow)
    end

    it "creates the subvolume with the correct mount point" do
      subvolume = filesystem.create_btrfs_subvolume(path, nocow)
      expect(subvolume.mount_point).to eq("/foo")
    end
  end

  describe "#btrfs_subvolume_path" do
    context "when the path is correct for the filesystem" do
      let(:path) { "@/foo" }

      it "returns the path" do
        expect(filesystem.btrfs_subvolume_path(path)).to eq(path)
      end
    end

    context "when the path is an absolute path" do
      let(:path) { "/foo" }

      it "returns a fixed path with the correct prefix for the filesystem" do
        expect(filesystem.btrfs_subvolume_path(path)).to eq("@/foo")
      end
    end

    context "when the path is a relative path" do
      let(:path) { "foo" }

      it "returns a fixed path with the correct prefix for the filesystem" do
        expect(filesystem.btrfs_subvolume_path(path)).to eq("@/foo")
      end
    end
  end

  describe "#btrfs_subvolume_mount_point" do
    before do
      allow(filesystem).to receive(:mount_point).and_return(mount_point)
    end

    context "when the filesystem is not mounted" do
      let(:mount_point) { nil }

      it "returns nil" do
        expect(filesystem.btrfs_subvolume_mount_point("@/foo")).to be_nil
      end
    end

    context "when the filesystem is mounted" do
      let(:mount_point) { "/var" }

      it "returns the subvolume mount point for the indicated path" do
        expect(filesystem.btrfs_subvolume_mount_point("@/foo")).to eq("/var/foo")
      end
    end
  end

  describe ".default_btrfs_subvolume_path" do
    before do
      allow(Yast::ProductFeatures).to receive(:GetSection).with("partitioning").and_return(section)
      allow(section).to receive(:key?).with("btrfs_default_subvolume").and_return(has_key)
      allow(Yast::ProductFeatures).to receive(:GetStringFeature)
        .with("partitioning", "btrfs_default_subvolume").and_return(default_subvolume)
    end

    let(:section) { double("section") }

    let(:default_subvolume) { "@" }

    context "when default btrfs subvolume is not specified in control.xml" do
      let(:has_key) { false }

      it "returns nil" do
        expect(described_class.default_btrfs_subvolume_path).to eq(nil)
      end
    end

    context "when default btrfs subvolume is specified in control.xml" do
      let(:has_key) { true }

      it "returns the specified default subvolume path" do
        expect(described_class.default_btrfs_subvolume_path).to eq(default_subvolume)
      end
    end
  end

  describe "#auto_deleted_subvolumes" do
    let(:subvol1) { Y2Storage::SubvolSpecification.new("path1") }
    let(:subvol2) { Y2Storage::SubvolSpecification.new("path2", copy_on_write: false) }

    it "returns an empty array by default" do
      expect(filesystem.auto_deleted_subvolumes).to eq []
    end

    it "allows to store a list of SubvolSpecification objects" do
      filesystem.auto_deleted_subvolumes = [subvol1, subvol2]

      expect(filesystem.auto_deleted_subvolumes).to all(be_a(Y2Storage::SubvolSpecification))
      expect(filesystem.auto_deleted_subvolumes).to contain_exactly(
        an_object_having_attributes(path: "path1", copy_on_write: true),
        an_object_having_attributes(path: "path2", copy_on_write: false)
      )
    end

    it "returns a copy of the stored objects instead of the original ones" do
      filesystem.auto_deleted_subvolumes = [subvol1, subvol2]

      expect(filesystem.auto_deleted_subvolumes).to_not eq [subvol1, subvol2]
    end

    it "shares the stored value with all the instances of the filesystem" do
      filesystem.auto_deleted_subvolumes = [subvol1, subvol2]

      another = Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name).filesystem
      expect(another.auto_deleted_subvolumes).to contain_exactly(
        an_object_having_attributes(path: "path1", copy_on_write: true),
        an_object_having_attributes(path: "path2", copy_on_write: false)
      )
    end

    it "gets copied when the devicegraph is cloned" do
      filesystem.auto_deleted_subvolumes = [subvol1, subvol2]
      new_graph = devicegraph.dup

      another = Y2Storage::BlkDevice.find_by_name(new_graph, dev_name).filesystem
      expect(another.auto_deleted_subvolumes).to contain_exactly(
        an_object_having_attributes(path: "path1", copy_on_write: true),
        an_object_having_attributes(path: "path2", copy_on_write: false)
      )
    end
  end

  describe ".refresh_root_subvolumes_shadowing" do
    before do
      filesystem.mount_point = mount_point
      allow(Y2Storage::Filesystems::BlkFilesystem).to receive(:all).and_return([filesystem])
    end

    context "when there is not a btrfs filesystem mounted as root" do
      let(:mount_point) { "/foo" }

      it "does not shadow subvolumes" do
        expect(filesystem).to_not receive(:shadow_btrfs_subvolumes)
        described_class.refresh_root_subvolumes_shadowing(devicegraph)
      end

      it "does not unshadow subvolumes" do
        expect(filesystem).to_not receive(:unshadow_btrfs_subvolumes)
        described_class.refresh_root_subvolumes_shadowing(devicegraph)
      end
    end

    context "when there is a btrfs filesystem mounted as root" do
      let(:mount_point) { "/" }

      it "shadows subvolumes of root filesystem" do
        expect(filesystem).to receive(:shadow_btrfs_subvolumes)
        described_class.refresh_root_subvolumes_shadowing(devicegraph)
      end

      it "unshadows subvolumes of root filesystem" do
        expect(filesystem).to receive(:unshadow_btrfs_subvolumes)
        described_class.refresh_root_subvolumes_shadowing(devicegraph)
      end
    end
  end

  describe "#shadow_btrfs_subvolumes" do
    before do
      partition.filesystem.mount_point = mount_point
      subvolume = filesystem.create_btrfs_subvolume(subvolume_path, false)
      subvolume.can_be_shadowed = can_be_shadowed
    end

    let(:partition) { Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sdb5") }

    let(:can_be_shadowed) { true }

    context "when any subvolume is shadowed" do
      let(:mount_point) { "/foo" }
      let(:subvolume_path) { "@/bar" }

      it "does not remove any subvolume" do
        subvolumes = filesystem.btrfs_subvolumes
        filesystem.shadow_btrfs_subvolumes(devicegraph)
        expect(filesystem.btrfs_subvolumes).to eq(subvolumes)
      end
    end

    context "when a subvolume is shadowed" do
      let(:mount_point) { "/foo" }
      let(:subvolume_path) { "@/foo/bar" }

      context "and the subvolume can be shadowed" do
        let(:can_be_shadowed) { true }

        it "removes the subvolume" do
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to_not be(nil)
          filesystem.shadow_btrfs_subvolumes(devicegraph)
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to be(nil)
        end

        it "adds the subvolume to the list of auto deleted subvolumes" do
          expect(filesystem.auto_deleted_subvolumes).to be_empty
          filesystem.shadow_btrfs_subvolumes(devicegraph)
          expect(filesystem.auto_deleted_subvolumes).to include(
            an_object_having_attributes(path: subvolume_path)
          )
        end
      end

      context "and the subvolume cannot be shadowed" do
        let(:can_be_shadowed) { false }

        it "does not remove the subvolume" do
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to_not be(nil)
          filesystem.shadow_btrfs_subvolumes(devicegraph)
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to_not be(nil)
        end

        it "does not add the subvolume to the list of auto deleted subvolumes" do
          expect(filesystem.auto_deleted_subvolumes).to be_empty
          filesystem.shadow_btrfs_subvolumes(devicegraph)
          expect(filesystem.auto_deleted_subvolumes).to be_empty
        end
      end
    end
  end

  describe ".unshadow_btrfs_subvolumes" do
    before do
      partition.filesystem.mount_point = mount_point
      filesystem.auto_deleted_subvolumes = shadowed_subvolumes
    end

    let(:partition) { Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sdb5") }

    let(:mount_point) { "" }

    context "when there are not shadowed subvolumes" do
      let(:shadowed_subvolumes) { [] }

      it "does not add subvolumes" do
        subvolumes = filesystem.btrfs_subvolumes
        filesystem.unshadow_btrfs_subvolumes(devicegraph)
        expect(filesystem.btrfs_subvolumes).to eq(subvolumes)
      end
    end

    context "when a subvolume was previously shadowed" do
      let(:shadowed_subvolumes) { [subvolume] }
      let(:subvolume) { Y2Storage::SubvolSpecification.new(subvolume_path) }

      context "and the subvolume is not shadowed yet" do
        let(:mount_point) { "/bar" }
        let(:subvolume_path) { "@/foo/bar" }

        it "adds the subvolume to the filesystem" do
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to be(nil)
          filesystem.unshadow_btrfs_subvolumes(devicegraph)
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to_not be(nil)
        end

        it "removes the subvolume from the list of auto deleted subvolumes" do
          expect(filesystem.auto_deleted_subvolumes).to include(
            an_object_having_attributes(path: subvolume_path)
          )

          filesystem.unshadow_btrfs_subvolumes(devicegraph)

          expect(filesystem.auto_deleted_subvolumes).to_not include(
            an_object_having_attributes(path: subvolume_path)
          )
        end
      end

      context "and the subvolume is still shadowed" do
        let(:mount_point) { "/foo" }
        let(:subvolume_path) { "@/foo/bar" }

        it "does not add the subvolume to the filesystem" do
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to be(nil)
          filesystem.unshadow_btrfs_subvolumes(devicegraph)
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to be(nil)

        end

        it "does not remove the subvolume from the list of auto deleted subvolumes" do
          expect(filesystem.auto_deleted_subvolumes).to include(
            an_object_having_attributes(path: subvolume_path)
          )

          filesystem.unshadow_btrfs_subvolumes(devicegraph)

          expect(filesystem.auto_deleted_subvolumes).to include(
            an_object_having_attributes(path: subvolume_path)
          )
        end
      end
    end
  end
end
