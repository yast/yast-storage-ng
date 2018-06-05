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
        expect(filesystem.btrfs_subvolumes).to include(an_object_having_attributes(path: path))
        filesystem.delete_btrfs_subvolume(devicegraph, path)
        expect(filesystem.btrfs_subvolumes).to_not include(an_object_having_attributes(path: path))
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

    context "when the default subvolume path is given" do
      let(:path) { "@" }

      it "removes the default subvolume" do
        filesystem.delete_btrfs_subvolume(devicegraph, path)

        expect(filesystem.btrfs_subvolumes).to_not include(an_object_having_attributes(path: "@"))
      end

      it "sets top level subvolume as default subvolume" do
        filesystem.delete_btrfs_subvolume(devicegraph, path)

        expect(filesystem.top_level_btrfs_subvolume).to eq(filesystem.default_btrfs_subvolume)
      end
    end

    context "when the top level subvolume path is given" do
      let(:path) { "" }

      it "does not delete any subvolume" do
        subvolumes_before = filesystem.btrfs_subvolumes
        filesystem.delete_btrfs_subvolume(devicegraph, path)
        expect(filesystem.btrfs_subvolumes).to eq(subvolumes_before)
      end
    end
  end

  describe "#create_btrfs_subvolume" do
    let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    let(:path1) { "@/foo" }
    let(:path2) { "@/foo/bar/baz" }
    let(:path3) { "@/foo/bar" }
    let(:nocow) { true }

    it "creates a new subvolume" do
      expect(filesystem.btrfs_subvolumes.map(&:path)).to_not include(path1)
      filesystem.create_btrfs_subvolume(path1, nocow)
      expect(filesystem.btrfs_subvolumes.map(&:path)).to include(path1)
    end

    it "returns the new created subvolume" do
      subvolume = filesystem.create_btrfs_subvolume(path1, nocow)
      expect(subvolume).to be_a(Y2Storage::BtrfsSubvolume)
      expect(subvolume.path).to eq(path1)
      expect(subvolume.nocow?).to eq(nocow)
    end

    it "creates the subvolume with the correct mount point" do
      subvolume = filesystem.create_btrfs_subvolume(path1, nocow)
      expect(subvolume.mount_path).to eq(path1.delete("@"))
    end

    context "when the filesystem is going to be formatted" do
      before do
        allow(filesystem).to receive(:exists_in_raw_probed?).and_return(false)
      end

      it "can insert a subvolume into an existing hierarchy" do
        filesystem.create_btrfs_subvolume(path2, nocow)
        filesystem.create_btrfs_subvolume(path3, nocow)
        expect(filesystem.btrfs_subvolumes.map(&:path)).to include(path3)
      end
    end

    context "when the filesystem already exists" do
      before do
        allow(filesystem).to receive(:exists_in_raw_probed?).and_return(true)
      end

      context "and the subvolume does not fit in the existing hierarchy" do
        before do
          filesystem.create_btrfs_subvolume(path2, nocow)
        end

        it "can not create a subvolume" do
          filesystem.create_btrfs_subvolume(path3, nocow)
          expect(filesystem.btrfs_subvolumes.map(&:path)).to_not include(path3)
        end

        it "and returns nil" do
          expect(filesystem.create_btrfs_subvolume(path3, nocow)).to be_nil
        end
      end
    end
  end

  describe "#canonical_subvolume_name" do
    it "converts subvolume name into the canonical form" do
      expect(filesystem.canonical_subvolume_name("foo")).to eq "foo"
      expect(filesystem.canonical_subvolume_name("/foo")).to eq "foo"
      expect(filesystem.canonical_subvolume_name("foo/bar")).to eq "foo/bar"
      expect(filesystem.canonical_subvolume_name("foo//bar////xxx//")).to eq "foo/bar/xxx"
      expect(filesystem.canonical_subvolume_name("///")).to eq ""
      expect(filesystem.canonical_subvolume_name("/")).to eq ""
      expect(filesystem.canonical_subvolume_name("")).to eq ""
    end
  end

  describe "#subvolume_descendants" do
    let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    let(:path1) { "@/foo" }
    let(:path2) { "@/foo/bar" }

    it "returns a list of descendant subvolumes" do
      filesystem.create_btrfs_subvolume(path1, false)
      filesystem.create_btrfs_subvolume(path2, false)
      subvolumes = filesystem.subvolume_descendants(path1)
      expect(subvolumes).to be_a Array
      expect(subvolumes).to all(be_a(Y2Storage::BtrfsSubvolume))
      expect(subvolumes.first.path).to eq path2
    end
  end

  describe "#subvolume_can_be_created?" do
    let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    let(:path1) { "@/foo" }
    let(:path2) { "@/foo/bar" }

    context "when the filesystem is going to be formatted" do
      before do
        allow(filesystem).to receive(:exists_in_raw_probed?).and_return(false)
      end

      context "and a subvolume must be inserted into an existing hierarchy" do
        it "returns true" do
          filesystem.create_btrfs_subvolume(path2, false)
          expect(filesystem.subvolume_can_be_created?(path1)).to be(true)
        end
      end

      context "and a subvolume must not be inserted into an existing hierarchy" do
        it "returns true" do
          filesystem.create_btrfs_subvolume(path1, false)
          expect(filesystem.subvolume_can_be_created?(path2)).to be(true)
        end
      end
    end

    context "when the filesystem already exists" do
      before do
        allow(filesystem).to receive(:exists_in_raw_probed?).and_return(true)
      end

      context "and a subvolume must be inserted into an existing hierarchy" do
        it "returns false" do
          filesystem.create_btrfs_subvolume(path2, false)
          expect(filesystem.subvolume_can_be_created?(path1)).to be(false)
        end
      end

      context "and a subvolume must not be inserted into an existing hierarchy" do
        it "returns true" do
          filesystem.create_btrfs_subvolume(path1, false)
          expect(filesystem.subvolume_can_be_created?(path2)).to be(true)
        end
      end
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
        allow(Yast::Arch).to receive(:s390).and_return(false)
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
    context "when the subvolumes prefix is not empty" do
      context "and the path starts with the subvolumes prefix" do
        let(:path) { "@/foo" }

        it "returns the path" do
          expect(filesystem.btrfs_subvolume_path(path)).to eq(path)
        end
      end

      context "and the path is an absolute path" do
        let(:path) { "/foo" }

        it "returns a fixed path starting with the subvolumes prefix" do
          expect(filesystem.btrfs_subvolume_path(path)).to eq("@/foo")
        end
      end

      context "and the path is a relative path" do
        let(:path) { "foo" }

        it "returns a fixed path starting with the subvolumes prefix" do
          expect(filesystem.btrfs_subvolume_path(path)).to eq("@/foo")
        end
      end
    end

    context "when the subvolumes prefix is empty" do
      before do
        # The prefix is empty if there is no a single top parent subvolume
        # under the top level one.
        filesystem.top_level_btrfs_subvolume.create_btrfs_subvolume("@@")
      end

      context "and the path is an absolute path" do
        let(:path) { "/foo" }

        it "returns a fixed relative path without any prefix" do
          expect(filesystem.btrfs_subvolume_path(path)).to eq("foo")
        end
      end

      context "and the path is a relative path" do
        let(:path) { "foo" }

        it "returns the path" do
          expect(filesystem.btrfs_subvolume_path(path)).to eq("foo")
        end
      end
    end
  end

  describe "#btrfs_subvolume_mount_point" do
    before do
      allow(filesystem).to receive(:mount_path).and_return(mount_path)
    end

    context "when the filesystem is not mounted" do
      let(:mount_path) { nil }

      it "returns nil" do
        expect(filesystem.btrfs_subvolume_mount_point("@/foo")).to be_nil
      end
    end

    context "when the filesystem is mounted" do
      let(:mount_path) { "/var" }

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
      let(:mount_path) { nil }

      it "returns nil" do
        expect(described_class.btrfs_subvolume_mount_point(mount_path, path)).to be_nil
      end
    end

    context "when the subvolume path is nil" do
      let(:mount_path) { "/" }
      let(:path) { nil }

      it "returns nil" do
        expect(described_class.btrfs_subvolume_mount_point(mount_path, path)).to be(nil)
      end
    end

    context "when the filesystem is mounted" do
      let(:mount_path) { "/foo" }

      it "returns the subvolume mount point for the indicated path" do
        expect(described_class.btrfs_subvolume_mount_point(mount_path, path)).to eq("/foo/bar")
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
      filesystem.mount_path = mount_path
      allow(Y2Storage::Filesystems::BlkFilesystem).to receive(:all).and_return([filesystem])
    end

    context "when there is a root btrfs filesystem" do
      let(:mount_path) { "/" }

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
      let(:mount_path) { "/foo" }

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
      let(:mount_path) { "/" }

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
      partition.filesystem.mount_path = mount_path
      subvolume = filesystem.create_btrfs_subvolume(subvolume_path, false)
      subvolume.can_be_auto_deleted = can_be_auto_deleted
    end

    let(:partition) { Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sdb5") }

    let(:can_be_auto_deleted) { true }

    context "when any subvolume is shadowed" do
      let(:mount_path) { "/foo" }
      let(:subvolume_path) { "@/bar" }

      it "does not remove any subvolume" do
        subvolumes = filesystem.btrfs_subvolumes
        filesystem.remove_shadowed_subvolumes(devicegraph)
        expect(filesystem.btrfs_subvolumes).to eq(subvolumes)
      end
    end

    context "when a subvolume is shadowed" do
      let(:mount_path) { "/foo" }
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
      partition.filesystem.mount_path = mount_path
      filesystem.auto_deleted_subvolumes = shadowed_subvolumes
    end

    let(:partition) { Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sdb5") }

    let(:mount_path) { "" }

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
        let(:mount_path) { "/bar" }
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
        let(:mount_path) { "/foo" }
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

  describe "#subvolumes_prefix" do
    context "when there are no subvolumes" do
      let(:dev_name) { "/dev/sda2" }

      before do
        filesystem.delete_btrfs_subvolume(devicegraph, "@")
      end

      it "returns an empty string" do
        expect(filesystem.subvolumes_prefix).to eq("")
      end
    end

    context "when there is only a single parent subvolume" do
      context "and the subvolume is for snapshots" do
        let(:dev_name) { "/dev/sde1" }

        it "returns an empty string" do
          expect(filesystem.subvolumes_prefix).to eq("")
        end
      end

      context "and the subvolume is not for snapshots" do
        let(:dev_name) { "/dev/sda2" }

        it "returns the parent subvolume path" do
          expect(filesystem.subvolumes_prefix).to eq("@")
        end

        context "and the subvolume is not the default subvolume" do
          before do
            subvolume = filesystem.find_btrfs_subvolume_by_path("@/home")
            subvolume.set_default_btrfs_subvolume
          end

          it "returns the parent subvolume path" do
            expect(filesystem.subvolumes_prefix).to eq("@")
          end
        end
      end
    end

    context "when there are several subvolumes at first level" do
      context "and there is only one subvolume that is not for snapshots" do
        let(:dev_name) { "/dev/sde1" }

        before do
          filesystem.top_level_btrfs_subvolume.create_btrfs_subvolume("@")
        end

        it "returns the no snapshot subvolume path" do
          expect(subject.subvolumes_prefix).to eq("@")
        end
      end

      context "and there are several subvolumes that are not for snapshots" do
        let(:dev_name) { "/dev/sdd1" }

        it "returns an empty string" do
          expect(subject.subvolumes_prefix).to eq("")
        end
      end
    end
  end

  describe "#snapshots?" do
    let(:subvolumes_prefix) { "@" }

    before do
      allow(subject).to receive(:btrfs_subvolumes).and_return(subvolumes)
      allow(subject).to receive(:subvolumes_prefix).and_return(subvolumes_prefix)
    end

    context "when a subvolume for snapshots exists" do
      let(:subvolumes) do
        [
          instance_double(Y2Storage::BtrfsSubvolume, path: "@"),
          instance_double(Y2Storage::BtrfsSubvolume, path: "@/.snapshots")
        ]
      end

      it "returns true" do
        expect(subject.snapshots?).to eq(true)
      end
    end

    context "when no subvolume for snapshots exists" do
      let(:subvolumes) do
        [
          instance_double(Y2Storage::BtrfsSubvolume, path: "@"),
          instance_double(Y2Storage::BtrfsSubvolume, path: "@/srv")
        ]
      end

      it "returns false" do
        expect(subject.snapshots?).to eq(false)
      end

      context "but snapper will be configured" do
        before do
          allow(subject).to receive(:configure_snapper).and_return(true)
        end

        it "returns true" do
          expect(subject.snapshots?).to eq(true)
        end
      end
    end

    context "when subvolume prefix is empty" do
      let(:subvolumes_prefix) { "" }

      context "and a subvolume for snapshots exists" do
        let(:subvolumes) do
          [
            instance_double(Y2Storage::BtrfsSubvolume, path: ""),
            instance_double(Y2Storage::BtrfsSubvolume, path: ".snapshots")
          ]
        end

        it "returns true" do
          expect(subject.snapshots?).to eq(true)
        end
      end
    end
  end

  describe "#copy_mount_by_to_subvolumes" do
    let(:subvol_mount_points) { filesystem.btrfs_subvolumes.reject { |s| s.mount_point.nil? } }

    # Need some real methods here to avoid 'let' blocks being cached between
    # the 'before' block and the 'it' block. Notice that 'let!' does NOT
    # prevent that in this case: It would only reevaluate the block between
    # different examples, not between the 'before' block and the 'it' block
    # within the same example.
    def subvol_mount_bys
      subvol_mount_points.map { |m| m.mount_by.to_sym }
    end

    def btrfs_mount_by
      filesystem.mount_by.to_sym
    end

    before do
      # Assert the correct starting conditions
      expect(btrfs_mount_by).to eq :label
      expect(subvol_mount_bys).to all(eq :label)
    end

    it "copies the btrfs mount_by value to all subvolumes" do
      filesystem.mount_point.mount_by = Y2Storage::Filesystems::MountByType::UUID
      filesystem.copy_mount_by_to_subvolumes
      expect(btrfs_mount_by).to eq :uuid
      expect(subvol_mount_bys).to all(eq :uuid)
    end

    it "not using it keeps the previous mount_by value for all subvolumes" do
      filesystem.mount_point.mount_by = Y2Storage::Filesystems::MountByType::UUID
      expect(btrfs_mount_by).to eq :uuid
      expect(subvol_mount_bys).to all(eq :label)
    end
  end
end
