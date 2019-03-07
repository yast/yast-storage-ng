#!/usr/bin/env rspec
# encoding: utf-8
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

  let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

  before do
    allow(Yast::Mode).to receive(:auto).and_return(true)
  end

  describe "#propose" do
    before { fake_scenario(scenario) }
    let(:scenario) { "bcache1.xml" }
    let(:drive_device) { "/dev/bcache0" }
    let(:create) { true }
    let(:create_vdb1) { true }
    let(:init) { true }
    let(:ptable_type) { "msdos" }
    let(:root) do
      { "create" => create, "filesystem" => :btrfs, "format" => create, "mount" => "/",
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

    context "when the Bcache is not partitioned" do
      let(:ptable_type) { "none" }

      it "formats the Bcache" do
        proposal.propose
        bcache = proposal.devices.bcaches.first
        expect(bcache.filesystem.type).to eq(Y2Storage::Filesystems::Type::BTRFS)
        expect(bcache.filesystem.mount_point.path).to eq("/")
      end
    end

    context "when the Bcache must be partitioned" do
      it "creates and mounts a partition" do
        proposal.propose
        bcache = proposal.devices.bcaches.first
        partition = bcache.partitions.first
        expect(partition.filesystem.type).to eq(Y2Storage::Filesystems::Type::BTRFS)
        expect(partition.filesystem.mount_point.path).to eq("/")
      end
    end

    context "reusing a Bcache" do
      let(:init) { false }
      let(:create) { false }
      let(:create_vdb1) { false }

      it "does not create a new Bcache" do
        old_sid = fake_devicegraph.find_by_name("/dev/bcache0").sid
        proposal.propose
        bcache = proposal.devices.find_by_name("/dev/bcache0")
        expect(bcache.sid).to eq(old_sid)
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
          "partitions" => [ { "format" => create, "raid_name" => "/dev/md0" } ]
        }
      end

      let(:vdc) do
        {
          "device" => "/dev/vdc",
          "type" => :CT_DISK, "use" => "all", "disklabel" => "none",
          "partitions" => [ { "format" => create, "raid_name" => "/dev/md0" } ]
        }
      end

      it "creates a Bcache on top of the MD RAID" do
        proposal.propose
        bcache = proposal.devices.bcaches.first
        caching_device = bcache.bcache_cset.blk_devices.first
        expect(caching_device.name).to eq("/dev/md0p1")
      end
    end
  end
end
