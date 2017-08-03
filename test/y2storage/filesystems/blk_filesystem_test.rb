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
      let(:dev_name) { "/dev/sdb3" }

      it "returns false" do
        expect(filesystem.supports_btrfs_subvolumes?).to eq false
      end
    end
  end

  describe "#btrfs_subvolumes" do
    context "for a no-Btrfs filesystem" do
      let(:dev_name) { "/dev/sdb3" }

      it "returns an empty array" do
        expect(filesystem.btrfs_subvolumes).to eq []
      end
    end

    context "for a Btrfs filesystem" do
      let(:dev_name) { "/dev/sdb2" }

      it "returns an array of BtrfsSubvolume objects" do
        expect(filesystem.btrfs_subvolumes).to be_a Array
        expect(filesystem.btrfs_subvolumes).to all(be_a(Y2Storage::BtrfsSubvolume))
      end
    end
  end

  describe "#top_level_btrfs_subvolume" do
    context "for a no-Btrfs filesystem" do
      let(:dev_name) { "/dev/sdb3" }

      it "returns nil" do
        expect(filesystem.top_level_btrfs_subvolume).to eq nil
      end
    end

    context "for a Btrfs filesystem" do
      let(:dev_name) { "/dev/sdb2" }

      it "returns a subvolume with 5 as id" do
        expect(filesystem.top_level_btrfs_subvolume).to be_a Y2Storage::BtrfsSubvolume
        expect(filesystem.top_level_btrfs_subvolume.id).to eq 5

      end
    end
  end

  describe "#default_btrfs_subvolume" do
    context "for a no-Btrfs filesystem" do
      let(:dev_name) { "/dev/sda1" }

      it "returns nil" do
        expect(filesystem.default_btrfs_subvolume).to eq nil
      end
    end

    context "for a Btrfs filesystem" do
      let(:dev_name) { "/dev/sda2" }

      it "returns a BtrfsSubvolume object" do
        expect(filesystem.default_btrfs_subvolume).to be_a(Y2Storage::BtrfsSubvolume)
      end

      it "returns the default subvolume" do
        expect(filesystem.default_btrfs_subvolume.path).to eq("@")
      end
    end
  end

  describe "#default_btrfs_subvolume_path" do
    context "for a no-Btrfs filesystem" do
      let(:dev_name) { "/dev/sda1" }

      it "returns nil" do
        expect(filesystem.default_btrfs_subvolume_path).to eq nil
      end
    end

    context "for a Btrfs filesystem" do
      let(:dev_name) { "/dev/sda2" }

      it "returns the default path for a default btrfs subvolume" do
        expect(filesystem.default_btrfs_subvolume_path).to eq("@")
      end
    end
  end

  describe "#find_btrfs_subvolume_by_path" do
    context "for a no-Btrfs filesystem" do
      let(:dev_name) { "/dev/sda1" }

      it "returns nil" do
        expect(filesystem.find_btrfs_subvolume_by_path("")).to eq nil
      end
    end

    context "for a Btrfs filesystem" do
      let(:dev_name) { "/dev/sda2" }

      context "where exists a subvolume with the searched path" do
        it "returns the subvolume with that path" do
          path = "@/home"
          subvolume = filesystem.find_btrfs_subvolume_by_path(path)

          expect(subvolume).to be_a(Y2Storage::BtrfsSubvolume)
          expect(subvolume.path).to eq(path)
        end
      end

      context "where does not exist a subvolume with the searched path" do
        # TODO: Needed bindings for Storage::BtrfsSubvolumeNotFoundByPath
        xit "returns nil" do
          expect(filesystem.find_btrfs_subvolume_by_path("@/foo")).to be_nil
        end
      end
    end
  end

  describe "#ensure_default_btrfs_subvolume" do
    context "for a no-Btrfs filesystem" do
      let(:dev_name) { "/dev/sda1" }

      it "returns nil" do
        expect(filesystem.ensure_default_btrfs_subvolume).to eq nil
      end
    end

    context "for a Btrfs filesystem" do
      context "where the default subvolume is equal to the top level one" do
        let(:dev_name) { "/dev/sdb2" }

        it "creates a default subvolume with the correct path" do
          top_level = filesystem.top_level_btrfs_subvolume
          default = filesystem.default_btrfs_subvolume

          expect(default).to eq(top_level)
          expect(default.path).to eq("")

          default = filesystem.ensure_default_btrfs_subvolume

          expect(filesystem.default_btrfs_subvolume).to eq(default)
          expect(default.path).to eq(filesystem.default_btrfs_subvolume_path)
        end
      end

      context "where the default subvolume is different to the top level one" do
        let(:dev_name) { "/dev/sda2" }

        it "does not create a new subvolume" do
          subvolumes = filesystem.btrfs_subvolumes
          filesystem.ensure_default_btrfs_subvolume

          expect(filesystem.btrfs_subvolumes).to eq(subvolumes)
        end

        it "returns the current default subvolume" do
          default = filesystem.default_btrfs_subvolume

          expect(filesystem.ensure_default_btrfs_subvolume).to eq(default)
        end
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
