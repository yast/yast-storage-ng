#!/usr/bin/env rspec

#
# Copyright (c) [2019] SUSE LLC
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
require "y2storage"

describe Y2Storage::AutoinstProposal do
  using Y2Storage::Refinements::SizeCasts

  subject(:proposal) do
    described_class.new(
      partitioning: partitioning, devicegraph: fake_devicegraph, issues_list: issues_list
    )
  end

  let(:issues_list) { ::Installation::AutoinstIssues::List.new }
  let(:architecture) { :x86_64 }

  before do
    allow(Yast::Mode).to receive(:auto).and_return(true)
  end

  describe "#propose" do
    before { fake_scenario(scenario) }

    let(:scenario) { "bcache1.xml" }
    let(:drive_device) { "/dev/bcache0" }
    let(:create) { true }
    let(:init) { true }
    let(:ptable_type) { "msdos" }
    let(:format) { create }
    let(:root) do
      { "create" => create, "filesystem" => :btrfs, "format" => format, "mount" => "/",
        "partition_nr" => 1 }
    end

    let(:bcache0) do
      {
        "device" => drive_device, "type" => :CT_BCACHE, "use" => "all",
        "disklabel" => ptable_type, "partitions" => [root]
      }
    end

    let(:vda) do
      {
        "device" => "/dev/vda",
        "type" => :CT_DISK, "use" => "all", "initialize" => init, "disklabel" => "msdos",
        "partitions" =>
        [
          {
            "create" => true, "filesystem" => :swap, "format" => true, "mount" => "swap",
            "size" => 2.GiB
          },
          {
            "create" => create, "size" => "max", "bcache_backing_for" => drive_device
          }
        ]
      }
    end

    let(:vdb) do
      {
        "device" => "/dev/vdb",
        "type" => :CT_DISK, "use" => "all", "disklabel" => "none", "initialize" => init,
        "partitions" =>
          [
            {
              "format" => create, "bcache_caching_for" => [drive_device]
            }
          ]
      }
    end

    let(:partitioning) { [bcache0, vda, vdb] }

    it "creates the bcache device" do
      proposal.propose
      bcache = proposal.devices.bcaches.first
      expect(bcache).to be_a(Y2Storage::Bcache)
      expect(bcache.backing_device.name).to eq("/dev/vda2")
      expect(bcache.bcache_cset.blk_devices.map(&:name)).to include("/dev/vdb")
    end

    it "does not register any issue" do
      proposal.propose
      expect(issues_list).to be_empty
    end

    context "when the bcache is not partitioned" do
      let(:ptable_type) { "none" }

      it "formats the bcache" do
        proposal.propose
        bcache = proposal.devices.bcaches.first
        expect(bcache.filesystem.type).to eq(Y2Storage::Filesystems::Type::BTRFS)
        expect(bcache.filesystem.mount_point.path).to eq("/")
      end
    end

    context "when the bcache must be partitioned" do
      it "creates and mounts a partition" do
        proposal.propose
        bcache = proposal.devices.bcaches.first
        partition = bcache.partitions.first
        expect(partition.filesystem.type).to eq(Y2Storage::Filesystems::Type::BTRFS)
        expect(partition.filesystem.mount_point.path).to eq("/")
      end
    end

    context "when more than one backing device is specified for a bcache" do
      let(:vdc) do
        {
          "device" => "/dev/vdc", "type" => :CT_DISK, "use" => "all",
          "partitions" => [{ "format" => create, "bcache_caching_for" => [drive_device] }]
        }
      end
      let(:partitioning) { [bcache0, vda, vdb, vdc] }

      it "registers an issue" do
        proposal.propose
        issue = issues_list.to_a.find do |i|
          i.is_a?(Y2Storage::AutoinstIssues::MultipleBcacheMembers)
        end
        expect(issue.bcache_name).to eq(drive_device)
        expect(issue.role).to eq(:caching)
      end
    end

    context "when more than one caching device is specified for a bcache" do
      let(:vdc) do
        {
          "device" => "/dev/vdc", "type" => :CT_DISK, "use" => "all",
          "partitions" => [{ "format" => create, "bcache_backing_for" => drive_device }]
        }
      end
      let(:partitioning) { [bcache0, vda, vdb, vdc] }

      it "registers an issue" do
        proposal.propose
        issue = issues_list.to_a.find do |i|
          i.is_a?(Y2Storage::AutoinstIssues::MultipleBcacheMembers)
        end
        expect(issue.bcache_name).to eq(drive_device)
        expect(issue.role).to eq(:backing)
      end
    end

    context "reusing a bcache" do
      let(:init) { false }
      let(:create) { false }

      RSpec.shared_examples "reuse bcache" do
        it "does not create a new bcache" do
          old_sid = fake_devicegraph.find_by_name("/dev/bcache0").sid
          proposal.propose
          bcache = proposal.devices.find_by_name("/dev/bcache0")
          expect(bcache.sid).to eq(old_sid)
        end
      end

      include_examples "reuse bcache"

      context "if the bcache is directly formatted" do
        let(:ptable_type) { "none" }

        before do
          bcache0 = fake_devicegraph.find_by_name("/dev/bcache0")
          bcache0.remove_descendants
          bcache0.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
        end

        context "and the bcache should be reformatted" do
          let(:format) { true }

          include_examples "reuse bcache"

          it "formats the bcache as specified in the profile" do
            proposal.propose
            bcache = proposal.devices.find_by_name("/dev/bcache0")
            expect(bcache.filesystem.type).to eq(Y2Storage::Filesystems::Type::BTRFS)
            expect(bcache.filesystem.mount_point.path).to eq("/")
          end
        end

        context "and the bcache should be not be formatted" do
          let(:format) { false }

          include_examples "reuse bcache"

          it "mounts the existing bcache filesystem without destroying it" do
            proposal.propose
            bcache = proposal.devices.find_by_name("/dev/bcache0")
            expect(bcache.filesystem.type).to eq(Y2Storage::Filesystems::Type::EXT4)
            expect(bcache.filesystem.mount_point.path).to eq("/")
          end
        end
      end
    end

    # Regression test for bsc#1139783
    context "with a LVM LV as backing device" do
      let(:scenario) { "empty_disks" }

      let(:partitioning) { [bcache0, vg0, sda] }

      let(:vg0) do
        {
          "device" => "/dev/vg0", "type" => :CT_LVM, "partitions" => [
            { "lv_name" => "lv1", "bcache_backing_for" => "/dev/bcache0" }
          ]
        }
      end

      let(:sda) do
        {
          "device" => "/dev/sda",
          "type" => :CT_DISK, "use" => "all", "disklabel" => "none",
          "partitions" => [{ "lvm_group" => "vg0" }]
        }
      end

      it "creates a bcache with a LVM LV as backing device" do
        proposal.propose
        bcache = proposal.devices.find_by_name("/dev/bcache0")

        expect(bcache.backing_device.name).to eq("/dev/vg0/lv1")
      end
    end

    # Regression test for bsc#1139783
    context "with a LVM LV as caching device" do
      let(:scenario) { "empty_disks" }

      let(:partitioning) { [bcache0, vg0, sda] }

      let(:vg0) do
        {
          "device" => "/dev/vg0", "type" => :CT_LVM, "partitions" => [
            { "lv_name" => "lv1", "bcache_caching_for" => ["/dev/bcache0"] }
          ]
        }
      end

      let(:sda) do
        {
          "device" => "/dev/sda",
          "type" => :CT_DISK, "use" => "all", "disklabel" => "gpt",
          "partitions" => [
            { "lvm_group" => "vg0" },
            { "bcache_backing_for" => "/dev/bcache0" }
          ]
        }
      end

      it "creates a bcache with a LVM LV as caching device" do
        proposal.propose
        bcache = proposal.devices.find_by_name("/dev/bcache0")

        expect(bcache.bcache_cset.blk_devices.first.name).to eq("/dev/vg0/lv1")
      end
    end

    # Regression test for bsc#1139783
    context "with an existing LVM LV as backing device" do
      let(:scenario) { "trivial_lvm" }

      let(:partitioning) { [bcache0, vg0] }

      let(:vg0) do
        {
          "device" => "/dev/vg0", "type" => :CT_LVM, "partitions" => [
            { "create" => false, "lv_name" => "lv1", "bcache_backing_for" => "/dev/bcache0" }
          ]
        }
      end

      it "creates a bcache with an existing LVM LV as backing device" do
        sid = fake_devicegraph.find_by_name("/dev/vg0/lv1").sid

        proposal.propose

        bcache = proposal.devices.find_by_name("/dev/bcache0")
        backing_device = bcache.backing_device

        expect(backing_device.name).to eq("/dev/vg0/lv1")
        expect(backing_device.sid).to eq(sid)
      end
    end

    # Regression test for bsc#1139783
    context "with an existing LVM LV as caching device" do
      let(:scenario) { "trivial_lvm_and_other_partitions" }

      let(:partitioning) { [bcache0, vg0, sda] }

      let(:vg0) do
        {
          "device" => "/dev/vg0", "type" => :CT_LVM, "partitions" => [
            { "create" => false, "lv_name" => "lv1", "bcache_caching_for" => ["/dev/bcache0"] }
          ]
        }
      end

      let(:sda) do
        {
          "device" => "/dev/sda",
          "type" => :CT_DISK, "use" => "all", "disklabel" => "gpt",
          "partitions" => [
            { "bcache_backing_for" => "/dev/bcache0" }
          ]
        }
      end

      it "creates a bcache with an existing LVM LV as caching device" do
        sid = fake_devicegraph.find_by_name("/dev/vg0/lv1").sid

        proposal.propose

        bcache = proposal.devices.find_by_name("/dev/bcache0")
        caching_device = bcache.bcache_cset.blk_devices.first

        expect(caching_device.name).to eq("/dev/vg0/lv1")
        expect(caching_device.sid).to eq(sid)
      end
    end

    context "on top of an MD RAID" do
      let(:partitioning) { [bcache0, md0, vda, vdb, vdc] }

      let(:md0) do
        {
          "device" => "/dev/md0", "type" => :CT_MD, "use" => "all",
          "disklabel" => "msdos", "partitions" => [
            { "create" => true, "bcache_caching_for" => ["/dev/bcache0"] }
          ]
        }
      end

      let(:vdb) do
        {
          "device" => "/dev/vdb",
          "type" => :CT_DISK, "use" => "all", "disklabel" => "none",
          "partitions" => [{ "format" => create, "raid_name" => "/dev/md0" }]
        }
      end

      let(:vdc) do
        {
          "device" => "/dev/vdc",
          "type" => :CT_DISK, "use" => "all", "disklabel" => "none",
          "partitions" => [{ "format" => create, "raid_name" => "/dev/md0" }]
        }
      end

      it "creates a bcache on top of the MD RAID" do
        proposal.propose
        bcache = proposal.devices.bcaches.first
        caching_device = bcache.bcache_cset.blk_devices.first
        expect(caching_device.name).to eq("/dev/md0p1")
      end
    end

    context "on top of an existing MD RAID" do
      let(:scenario) { "partitioned_md" }
      let(:partitioning) { [bcache0, md0, sda, sdb] }

      let(:sda) do
        {
          "device" => "/dev/sda", "type" => :CT_DISK, "use" => "all",
          "partitions" => [
            { "create" => false, "partition_nr" => 1, "raid_name" => "/dev/md0" },
            { "create" => false, "partition_nr" => 2, "raid_name" => "/dev/md0" }
          ]
        }
      end

      let(:sdb) do
        {
          "device" => "/dev/sdb", "type" => :CT_DISK, "use" => "all",
          "partitions" => [
            { "create" => true, "partition_nr" => 1, "bcache_backing_for" => "/dev/bcache0" }
          ]
        }
      end

      let(:md0) do
        {
          "device" => "/dev/md0", "type" => :CT_MD, "use" => "all",
          "disklabel" => "msdos", "partitions" => [
            { "create" => false, "partition_nr" => 1, "bcache_caching_for" => ["/dev/bcache0"] }
          ]
        }
      end

      it "creates a bcache on top of the MD RAID" do
        proposal.propose
        bcache = proposal.devices.bcaches.first
        caching_device = bcache.bcache_cset.blk_devices.first
        expect(caching_device.name).to eq("/dev/md0p1")
      end
    end
  end
end
