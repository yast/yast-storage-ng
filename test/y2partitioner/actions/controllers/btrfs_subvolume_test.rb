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

require "y2partitioner/device_graphs"
require "y2partitioner/actions/controllers/btrfs_subvolume"

describe Y2Partitioner::Actions::Controllers::BtrfsSubvolume do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(filesystem, subvolume: subvolume) }

  let(:filesystem) { device.filesystem }

  let(:subvolume) { nil }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks_btrfs" }

  let(:device_name) { "/dev/sda2" }

  describe "#create_subvolume" do
    let(:shadower) { instance_double(Y2Storage::Shadower) }

    it "creates a new subvolume with the given attributes" do
      foo_subvolume = filesystem.btrfs_subvolumes.find { |s| s.path == "@/foo" }
      expect(foo_subvolume).to be_nil

      subject.create_subvolume("@/foo", true)

      expect(subject.subvolume).to_not be_nil
      expect(subject.subvolume.path).to eq("@/foo")
      expect(subject.subvolume.nocow?).to eq(true)
    end

    it "refreshes the shadowing of the subvolumes from the current filesystem" do
      expect(Y2Storage::Shadower).to receive(:new).with(anything, filesystems: [filesystem])
        .and_return(shadower)

      expect(shadower).to receive(:refresh_shadowing)

      subject.create_subvolume("@/foo", true)
    end
  end

  describe "#update_subvolume" do
    before do
      subject.subvolume_path = "@/bar"
      subject.subvolume_nocow = false
    end

    context "when the subvolume does not exist on disk yet" do
      let(:subvolume) { filesystem.create_btrfs_subvolume("@/foo", true) }

      it "removes the subvolume" do
        sid = subvolume.sid

        subject.update_subvolume

        expect(current_graph.find_device(sid)).to be_nil
      end

      it "creates a new subvolume with the given attributes" do
        subject.update_subvolume

        expect(subject.subvolume.path).to eq("@/bar")
        expect(subject.subvolume.nocow?).to eq(false)
      end
    end

    context "when the subvolume exists on disk" do
      let(:subvolume) { filesystem.btrfs_subvolumes.find { |s| s.path == "@/home" } }

      before do
        subvolume.nocow = true
      end

      it "does not remove the subvolume" do
        sid = subvolume.sid

        subject.update_subvolume

        expect(current_graph.find_device(sid)).to_not be_nil
      end

      it "updates the noCoW subvolume attribute" do
        expect(subvolume.nocow?).to eq(true)

        subject.update_subvolume

        expect(subvolume.nocow?).to eq(false)
      end

      it "does not modify the subvolume path" do
        subject.update_subvolume

        expect(subvolume.path).to eq("@/home")
      end
    end
  end

  describe "#subvolumes_prefix" do
    context "when the subvolumes prefix is empty for the current filesystem" do
      let(:device_name) { "/dev/sdd1" }

      it "returns an empty string" do
        expect(subject.subvolumes_prefix).to be_empty
      end
    end

    context "when the subvolumes prefix is not empty for the current filesystem" do
      let(:device_name) { "/dev/sda2" }

      it "returns the subvolumes prefix ending with /" do
        expect(subject.subvolumes_prefix).to eq("@/")
      end
    end
  end

  describe "#missing_subvolumes_prefix?" do
    context "when the given path does not start by the subvolumes prefix (after deleting slashes)" do
      it "returns true" do
        expect(subject.missing_subvolumes_prefix?("")).to eq(true)
        expect(subject.missing_subvolumes_prefix?("foo")).to eq(true)
        expect(subject.missing_subvolumes_prefix?("/foo")).to eq(true)
        expect(subject.missing_subvolumes_prefix?("///foo")).to eq(true)
      end
    end

    context "when the given path starts by the subvolumes prefix (after deleting slashes)" do
      it "returns false" do
        expect(subject.missing_subvolumes_prefix?("@/")).to eq(false)
        expect(subject.missing_subvolumes_prefix?("@/foo")).to eq(false)
        expect(subject.missing_subvolumes_prefix?("//@//foo")).to eq(false)
      end
    end
  end

  describe "#add_subvolumes_prefix" do
    context "when the given path already starts by the subvolumes prefix (after deleting slashes)" do
      it "returns the given path" do
        expect(subject.add_subvolumes_prefix("@/")).to eq("@/")
        expect(subject.add_subvolumes_prefix("@/foo")).to eq("@/foo")
        expect(subject.add_subvolumes_prefix("//@//foo")).to eq("//@//foo")
      end
    end

    context "when the given path does not start by the subvolumes prefix (after deleting slashes)" do
      it "prepends the suvolumes prefix to the given path" do
        expect(subject.add_subvolumes_prefix("")).to eq("@/")
        expect(subject.add_subvolumes_prefix("foo")).to eq("@/foo")
        expect(subject.add_subvolumes_prefix("/foo")).to eq("@/foo")
        expect(subject.add_subvolumes_prefix("///foo")).to eq("@/foo")
        expect(subject.add_subvolumes_prefix("///foo//bar")).to eq("@/foo/bar")
      end
    end
  end

  describe "#exist_subvolume?" do
    context "when there is not a specific subvolume" do
      let(:subvolume) { nil }

      it "returns false" do
        expect(subject.exist_subvolume?).to eq(false)
      end
    end

    context "when there is a subvolume" do
      context "and the subvolume does not exist on disk yet" do
        let(:subvolume) { filesystem.create_btrfs_subvolume("@/foo", true) }

        it "returns false" do
          expect(subject.exist_subvolume?).to eq(false)
        end
      end

      context "and the subvolume exists on disk" do
        let(:subvolume) { filesystem.btrfs_subvolumes.find { |s| s.path == "@/home" } }

        it "returns true" do
          expect(subject.exist_subvolume?).to eq(true)
        end
      end
    end
  end

  describe "#exist_path?" do
    context "when the filesystem already has a subvolume with the given path" do
      it "returns true" do
        expect(subject.exist_path?("@/home")).to eq(true)
      end
    end

    context "when the filesystem has not a subvolume with the given path" do
      it "returns false" do
        expect(subject.exist_path?("@/foo")).to eq(false)
      end
    end
  end

  describe "#quota?" do
    context "when quotas are active in the filesystem" do
      before do
        filesystem.quota = true
      end

      it "returns true" do
        expect(subject.quota?).to eq true
      end
    end

    context "when quotas are active in the filesystem" do
      it "returns false" do
        expect(subject.quota?).to eq false
      end
    end
  end

  describe "#fallback_referenced_limit" do
    context "when there is not a specific subvolume" do
      let(:subvolume) { nil }

      it "returns the size of the filesystem" do
        expect(subject.fallback_referenced_limit).to eq device.size
      end
    end

    context "when there is a subvolume" do
      before { filesystem.quota = true }
      let(:subvolume) { filesystem.create_btrfs_subvolume("@/foo", true) }

      context "and the subvolume has still not had any limit" do
        it "returns the size of the filesystem" do
          expect(subject.fallback_referenced_limit).to eq device.size
        end
      end

      context "and the subvolume used to have a limit" do
        before do
          subvolume.referenced_limit = Y2Storage::DiskSize.MiB(300)
          subvolume.referenced_limit = Y2Storage::DiskSize.unlimited
        end

        it "returns the former limit" do
          expect(subject.fallback_referenced_limit).to eq Y2Storage::DiskSize.MiB(300)
        end
      end
    end
  end
end
