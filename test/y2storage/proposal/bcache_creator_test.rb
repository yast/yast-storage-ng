#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::Proposal::BcacheCreator do
  using Y2Storage::Refinements::SizeCasts

  subject(:creator) { described_class.new(fake_devicegraph) }

  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "windows-linux-free-pc" }

  let(:planned_bcache0) do
    planned_bcache(
      name: "/dev/bcache0", partitions: partitions, ptable_type: ptable_type,
      cache_mode: Y2Storage::CacheMode::WRITEBACK
    )
  end
  let(:caching_devname) { "/dev/sda3" }
  let(:backing_devname) { "/dev/sdb" }
  let(:ptable_type) { Y2Storage::PartitionTables::Type::GPT }
  let(:partitions) { [root] }
  let(:root) do
    planned_partition(
      mount_point: "/", type: Y2Storage::Filesystems::Type::BTRFS, min_size: 1.GiB, max_size: 1.GiB
    )
  end

  describe "#create_bcache" do
    it "creates a new bcache device" do
      result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
      bcache = result.devicegraph.find_by_name("/dev/bcache0")
      expect(bcache.name).to eq("/dev/bcache0")
    end

    it "sets the bcache mode" do
      result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
      bcache = result.devicegraph.find_by_name("/dev/bcache0")
      expect(bcache.cache_mode).to eq(Y2Storage::CacheMode::WRITEBACK)
    end

    it "adds caching devices to bcache" do
      result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
      devicegraph = result.devicegraph
      bcache = devicegraph.find_by_name("/dev/bcache0")
      expect(bcache.backing_device.name).to eq(backing_devname)
    end

    it "adds the backing device to bcache" do
      result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
      devicegraph = result.devicegraph
      bcache = devicegraph.find_by_name("/dev/bcache0")
      caching_device = devicegraph.find_by_name(caching_devname)
      expect(caching_device.descendants).to include(bcache)
    end

    context "when no partitions are specified" do
      let(:partitions) { [] }

      it "does not add any partition" do
        result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
        bcache = result.devicegraph.bcaches.first
        expect(bcache.partitions).to be_empty
      end
    end

    it "creates a partition table of the wanted type" do
      result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
      bcache = result.devicegraph.bcaches.first
      expect(bcache.partition_table.type).to eq(ptable_type)
    end

    context "when no partition type is specified" do
      let(:ptable_type) { nil }

      it "creates a partition table of the default type" do
        result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
        bcache = result.devicegraph.bcaches.first
        expect(bcache.partition_table.type).to eq(bcache.preferred_ptable_type)
      end
    end

    context "when partition sizes are specified as percentages" do
      let(:root) do
        planned_partition(
          mount_point: "/", type: Y2Storage::Filesystems::Type::BTRFS, percent_size: 50
        )
      end

      it "adds the partitions with the correct size" do
        result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
        bcache = result.devicegraph.bcaches.first
        part0 = bcache.partitions.first
        expect(part0.size.to_i).to be_within(0.5.MiB.to_i).of((bcache.size / 2).to_i)
      end
    end

    context "when partitions does not fit" do
      let(:root) do
        planned_partition(
          mount_point: "/", type: Y2Storage::Filesystems::Type::BTRFS, min_size: 1.TiB
        )
      end

      it "raises a NoDiskSpaceError" do
        expect { creator.create_bcache(planned_bcache0, backing_devname, caching_devname) }
          .to raise_error(Y2Storage::NoDiskSpaceError)
      end
    end

    context "reusing a bcache" do
      let(:scenario) { "bcache1.xml" }
      let(:real_bcache) { fake_devicegraph.bcaches.first }
      ORIGINAL_BACKING_DEVNAME = "/dev/vdc"
      ORIGINAL_CACHING_DEVNAME = "/dev/vdb"

      before do
        planned_bcache0.reuse_name = real_bcache.name
        real_bcache.remove_descendants
      end

      it "does not create a new bcache" do
        result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
        expect(result.devicegraph.bcaches.size).to eq(3)
      end

      it "does not change the backing nor caching device" do
        result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
        updated_bcache = result.devicegraph.bcaches.first
        expect(updated_bcache.backing_device.name).to eq(ORIGINAL_BACKING_DEVNAME)
        expect(updated_bcache.bcache_cset.blk_devices.map(&:name)).to eq([ORIGINAL_CACHING_DEVNAME])
      end

      context "when there are planned partitions" do
        it "adds new partitions to the existing bcache" do
          result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
          bcache = result.devicegraph.bcaches.first
          part0 = bcache.partitions.first
          expect(part0.mount_point.path).to eq("/")
          expect(part0.size).to eq(1.GiB)
        end
      end

      context "when a partition table type is specified" do
        let(:ptable_type) { Y2Storage::PartitionTables::Type::MSDOS }

        context "and a partition table already exists" do
          before do
            real_bcache.create_partition_table(Y2Storage::PartitionTables::Type::MSDOS)
          end

          it "replaces the partition table for one of the wanted type" do
            result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
            bcache = result.devicegraph.bcaches.first
            expect(bcache.partition_table.type).to eq(ptable_type)
          end
        end

        context "and the bcache contains a partition" do
          before do
            real_bcache.create_partition_table(Y2Storage::PartitionTables::Type::MSDOS)
            region = real_bcache.free_spaces.first.region
            region.length = region.length / 2
            ptable = real_bcache.partition_table
            slot = ptable.unused_slot_for(region)
            ptable.create_partition(slot.name, region, Y2Storage::PartitionType::PRIMARY)
          end

          it "does not modify the current partition table" do
            result = creator.create_bcache(planned_bcache0, backing_devname, caching_devname)
            bcache = result.devicegraph.bcaches.first
            expect(bcache.partition_table.type).to eq(Y2Storage::PartitionTables::Type::MSDOS)
          end
        end
      end
    end
  end

  describe "#reuse_partitions" do
    let(:scenario) { "bcache1.xml" }
    let(:real_bcache) { fake_devicegraph.bcaches.first }

    before do
      planned_bcache0.reuse_name = real_bcache.name
      root.reuse_name = "/dev/bcache0p1"
    end

    it "reuses the partitions" do
      devicegraph = creator.reuse_partitions(planned_bcache0).devicegraph
      reused_bcache = devicegraph.bcaches.first
      mount_point = reused_bcache.partitions.first.mount_point
      expect(mount_point.path).to eq("/")
    end
  end
end
