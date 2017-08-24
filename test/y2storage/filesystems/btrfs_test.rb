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

  describe "#add_btrfs_subvolumes" do
    let(:specs) { [spec1, spec2] }

    context "when subvolumes for the indicated specs do not exist" do
      let(:spec1) { Y2Storage::SubvolSpecification.new("foo") }
      let(:spec2) { Y2Storage::SubvolSpecification.new("bar") }

      it "creates the subvolumes indicated in specs" do
        expect(filesystem.find_btrfs_subvolume_by_path("@/foo")).to be_nil
        expect(filesystem.find_btrfs_subvolume_by_path("@/bar")).to be_nil

        filesystem.add_btrfs_subvolumes(specs)

        expect(filesystem.find_btrfs_subvolume_by_path("@/foo")).to_not be_nil
        expect(filesystem.find_btrfs_subvolume_by_path("@/bar")).to_not be_nil
      end

      it "creates new subvolumes as 'can be auto deleted'" do
        filesystem.add_btrfs_subvolumes(specs)
        expect(filesystem.find_btrfs_subvolume_by_path("@/foo").can_be_auto_deleted?).to eq(true)
        expect(filesystem.find_btrfs_subvolume_by_path("@/bar").can_be_auto_deleted?).to eq(true)
      end

      it "does not set the existing subvolumes as 'can be deleted'" do
        filesystem.add_btrfs_subvolumes(specs)
        expect(filesystem.find_btrfs_subvolume_by_path("@/home").can_be_auto_deleted?).to eq(false)
      end
    end

    context "when a subvolume already exists" do
      let(:spec1) { Y2Storage::SubvolSpecification.new("foo") }
      let(:spec2) { Y2Storage::SubvolSpecification.new("home") }

      it "does not create the subvolume again" do
        home_subvolume = filesystem.find_btrfs_subvolume_by_path("@/home")
        filesystem.add_btrfs_subvolumes(specs)
        home_subvolumes = filesystem.btrfs_subvolumes.select { |s| s.path == "@/home" }

        expect(home_subvolumes.size).to eq(1)
        expect(home_subvolume).to eq(home_subvolumes.first)
      end
    end

    context "when a subvolume spec is not for the current arch" do
      before do
        allow(Yast::Arch).to receive(:x86_64).and_return(true)
      end

      let(:spec1) { Y2Storage::SubvolSpecification.new("foo") }
      let(:spec2) { Y2Storage::SubvolSpecification.new("bar", archs: ["s390"]) }

      it "does not create the subvolume for other archs" do
        filesystem.add_btrfs_subvolumes(specs)
        expect(filesystem.find_btrfs_subvolume_by_path("@/bar")).to be_nil
      end
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

  describe ".btrfs_subvolume_path" do
    let(:default_subvolume_path) { "@" }
    let(:path) { "foo" }

    it "creates a subvolume path" do
      expect(described_class.btrfs_subvolume_path(default_subvolume_path, path)).to eq("@/foo")
    end

    context "when the default subvolume path is nil" do
      let(:default_subvolume_path) { nil }

      it "returns nil" do
        expect(described_class.btrfs_subvolume_path(default_subvolume_path, path)).to be(nil)
      end
    end

    context "when the subvolume path is nil" do
      let(:path) { nil }

      it "returns nil" do
        expect(described_class.btrfs_subvolume_path(default_subvolume_path, path)).to be(nil)
      end
    end
  end

  describe ".btrfs_subvolume_mount_point" do
    let(:path) { "bar" }

    context "when the filesystem is not mounted" do
      let(:mount_point) { nil }

      it "returns nil" do
        expect(described_class.btrfs_subvolume_mount_point(mount_point, path)).to be_nil
      end
    end

    context "when the subvolume path is nil" do
      let(:mount_point) { "/" }
      let(:path) { nil }

      it "returns nil" do
        expect(described_class.btrfs_subvolume_mount_point(mount_point, path)).to be(nil)
      end
    end

    context "when the filesystem is mounted" do
      let(:mount_point) { "/foo" }

      it "returns the subvolume mount point for the indicated path" do
        expect(described_class.btrfs_subvolume_mount_point(mount_point, path)).to eq("/foo/bar")
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

  describe ".refresh_subvolumes_shadowing" do
    before do
      filesystem.mount_point = mount_point
      allow(Y2Storage::Filesystems::BlkFilesystem).to receive(:all).and_return([filesystem])
    end

    context "when there is a root btrfs filesystem" do
      let(:mount_point) { "/" }

      it "shadows subvolumes of root filesystem" do
        expect(filesystem).to receive(:remove_shadowed_subvolumes)
        described_class.refresh_subvolumes_shadowing(devicegraph)
      end

      it "unshadows subvolumes of root filesystem" do
        expect(filesystem).to receive(:restore_unshadowed_subvolumes)
        described_class.refresh_subvolumes_shadowing(devicegraph)
      end
    end

    context "when there is a not root btrfs filesystem" do
      let(:mount_point) { "/foo" }

      it "shadows subvolumes of the filesystem" do
        expect(filesystem).to receive(:remove_shadowed_subvolumes)
        described_class.refresh_subvolumes_shadowing(devicegraph)
      end

      it "unshadows subvolumes of the filesystem" do
        expect(filesystem).to receive(:restore_unshadowed_subvolumes)
        described_class.refresh_subvolumes_shadowing(devicegraph)
      end
    end

    context "when there is a not btrfs filesystem" do
      let(:mount_point) { "/" }

      before do
        allow(filesystem).to receive(:supports_btrfs_subvolumes?).and_return(false)
      end

      it "does not try to shadow subvolumes for the filesystem" do
        expect(filesystem).to_not receive(:remove_shadowed_subvolumes)
        described_class.refresh_subvolumes_shadowing(devicegraph)
      end

      it "does not try to unshadow subvolumes for the filesystem" do
        expect(filesystem).to_not receive(:restore_unshadowed_subvolumes)
        described_class.refresh_subvolumes_shadowing(devicegraph)
      end
    end
  end

  describe "#remove_shadowed_subvolumes" do
    before do
      partition.filesystem.mount_point = mount_point
      subvolume = filesystem.create_btrfs_subvolume(subvolume_path, false)
      subvolume.can_be_auto_deleted = can_be_auto_deleted
    end

    let(:partition) { Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sdb5") }

    let(:can_be_auto_deleted) { true }

    context "when any subvolume is shadowed" do
      let(:mount_point) { "/foo" }
      let(:subvolume_path) { "@/bar" }

      it "does not remove any subvolume" do
        subvolumes = filesystem.btrfs_subvolumes
        filesystem.remove_shadowed_subvolumes(devicegraph)
        expect(filesystem.btrfs_subvolumes).to eq(subvolumes)
      end
    end

    context "when a subvolume is shadowed" do
      let(:mount_point) { "/foo" }
      let(:subvolume_path) { "@/foo/bar" }

      context "and the subvolume can be auto deleted" do
        let(:can_be_auto_deleted) { true }

        it "removes the subvolume" do
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to_not be(nil)
          filesystem.remove_shadowed_subvolumes(devicegraph)
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to be(nil)
        end

        it "adds the subvolume to the list of auto deleted subvolumes" do
          expect(filesystem.auto_deleted_subvolumes).to be_empty
          filesystem.remove_shadowed_subvolumes(devicegraph)
          expect(filesystem.auto_deleted_subvolumes).to include(
            an_object_having_attributes(path: subvolume_path)
          )
        end
      end

      context "and the subvolume cannot be auto deleted" do
        let(:can_be_auto_deleted) { false }

        it "does not remove the subvolume" do
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to_not be(nil)
          filesystem.remove_shadowed_subvolumes(devicegraph)
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to_not be(nil)
        end

        it "does not add the subvolume to the list of auto deleted subvolumes" do
          expect(filesystem.auto_deleted_subvolumes).to be_empty
          filesystem.remove_shadowed_subvolumes(devicegraph)
          expect(filesystem.auto_deleted_subvolumes).to be_empty
        end
      end
    end
  end

  describe "#restore_unshadowed_subvolumes" do
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
        filesystem.restore_unshadowed_subvolumes(devicegraph)
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
          filesystem.restore_unshadowed_subvolumes(devicegraph)
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to_not be(nil)
        end

        it "removes the subvolume from the list of auto deleted subvolumes" do
          expect(filesystem.auto_deleted_subvolumes).to include(
            an_object_having_attributes(path: subvolume_path)
          )

          filesystem.restore_unshadowed_subvolumes(devicegraph)

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
          filesystem.restore_unshadowed_subvolumes(devicegraph)
          expect(filesystem.find_btrfs_subvolume_by_path(subvolume_path)).to be(nil)

        end

        it "does not remove the subvolume from the list of auto deleted subvolumes" do
          expect(filesystem.auto_deleted_subvolumes).to include(
            an_object_having_attributes(path: subvolume_path)
          )

          filesystem.restore_unshadowed_subvolumes(devicegraph)

          expect(filesystem.auto_deleted_subvolumes).to include(
            an_object_having_attributes(path: subvolume_path)
          )
        end
      end
    end
  end
end
