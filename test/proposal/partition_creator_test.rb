#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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
require "storage"
require "storage/proposal"
require "storage/refinements/devicegraph_lists"
require "storage/refinements/size_casts"

describe Yast::Storage::Proposal::PartitionCreator do
  describe "#create_partitions" do
    using Yast::Storage::Refinements::SizeCasts
    using Yast::Storage::Refinements::DevicegraphLists

    before do
      fake_scenario(scenario)
    end

    let(:root_vol) { planned_vol(mount_point: "/", type: :ext4, desired: 1.GiB) }
    let(:home_vol) { planned_vol(mount_point: "/home", type: :ext4, desired: 1.GiB) }
    let(:swap_vol) { planned_vol(mount_point: "swap", type: :swap, desired: 1.GiB) }
    let(:disk_spaces) { fake_devicegraph.free_disk_spaces.to_a }

    subject(:creator) { described_class.new(fake_devicegraph) }

    let(:scenario) { "spaces_3_8_two_disks" }

    it "creates the partitions honouring the distribution" do
      space3 = disk_spaces.detect { |s| s.size == 3.GiB }
      space8 = disk_spaces.detect { |s| s.size == 8.GiB }
      distribution = space_dist(
        space3 => vols_list(root_vol, home_vol),
        space8 => vols_list(swap_vol)
      )

      result = creator.create_partitions(distribution)
      sda = result.disks.with(name: "/dev/sda")
      sdb = result.disks.with(name: "/dev/sdb")

      expect(sda.partitions).to contain_exactly(
        an_object_with_fields(mountpoint: "/"),
        an_object_with_fields(mountpoint: "/home"),
        an_object_with_fields(mountpoint: nil)
      )
      expect(sdb.partitions).to contain_exactly(
        an_object_with_fields(mountpoint: "swap"),
        an_object_with_fields(mountpoint: nil)
      )
    end

    context "when filling a space with several volumes" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:distribution) do
        space_dist(disk_spaces.first => vols_list(root_vol, home_vol, swap_vol))
      end

      context "if the exact space is available" do
        before do
          root_vol.desired = 20.GiB
          home_vol.desired = 20.GiB
          swap_vol.desired = 10.GiB
        end

        it "creates partitions matching the volume sizes" do
          result = creator.create_partitions(distribution)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(mountpoint: "/", size: 20.GiB),
            an_object_with_fields(mountpoint: "/home", size: 20.GiB),
            an_object_with_fields(mountpoint: "swap", size: 10.GiB)
          )
        end
      end

      context "if some extra space is available" do
        before do
          root_vol.desired = 20.GiB
          root_vol.weight = 1
          home_vol.desired = 20.GiB
          home_vol.weight = 2
          swap_vol.desired = 1.GiB
          swap_vol.max_size = 1.GiB
        end

        it "distributes the extra space" do
          result = creator.create_partitions(distribution)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(mountpoint: "/", size: 23.GiB),
            an_object_with_fields(mountpoint: "/home", size: 26.GiB),
            an_object_with_fields(mountpoint: "swap", size: 1.GiB)
          )
        end
      end
    end

    context "when creating partitions in an empty space" do
      let(:scenario) { "space_22" }
      let(:distribution) do
        space_dist(disk_spaces.first => vols_list(root_vol, home_vol))
      end

      context "if the space is marked as :primary" do
        before do
          allow(distribution.spaces.first).to receive(:partition_type).and_return :primary
        end

        it "creates all partitions as primary" do
          result = creator.create_partitions(distribution)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda1"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda2"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, mountpoint: "/"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, mountpoint: "/home")
          )
        end
      end

      context "if the space is marked as :extended" do
        before do
          allow(distribution.spaces.first).to receive(:partition_type).and_return :extended
        end

        it "creates no new primary partitions" do
          result = creator.create_partitions(distribution)
          primary = result.partitions.with(type: ::Storage::PartitionType_PRIMARY)
          expect(primary).to contain_exactly(
            an_object_with_fields(name: "/dev/sda1", size: 78.GiB),
            an_object_with_fields(name: "/dev/sda2", size: 100.GiB)
          )
        end

        it "creates an extended partition filling the whole space" do
          result = creator.create_partitions(distribution)
          extended = result.partitions.with(type: ::Storage::PartitionType_EXTENDED)
          expect(extended).to contain_exactly an_object_with_fields(name: "/dev/sda3", size: 22.GiB)
        end

        it "creates all the partitions as logical" do
          result = creator.create_partitions(distribution)
          logical = result.partitions.with(type: ::Storage::PartitionType_LOGICAL)
          expect(logical).to contain_exactly(
            an_object_with_fields(name: "/dev/sda5", size: 1.GiB),
            an_object_with_fields(name: "/dev/sda6", size: 1.GiB)
          )
        end
      end

      context "if the space has not predefined partition type" do
        before do
          allow(distribution.spaces.first).to receive(:partition_type).and_return nil
        end

        it "creates as many primary partitions as possible" do
          result = creator.create_partitions(distribution)
          primary = result.partitions.with(type: ::Storage::PartitionType_PRIMARY)
          expect(primary).to contain_exactly(
            an_object_with_fields(name: "/dev/sda1", size: 78.GiB),
            an_object_with_fields(name: "/dev/sda2", size: 100.GiB),
            an_object_with_fields(name: "/dev/sda3", size: 1.GiB)
          )
        end

        it "creates an extended partition filling the remaining space" do
          result = creator.create_partitions(distribution)
          extended = result.partitions.with(type: ::Storage::PartitionType_EXTENDED)
          expect(extended).to contain_exactly an_object_with_fields(name: "/dev/sda4", size: 21.GiB)
        end

        it "creates logical partitions for the remaining volumes" do
          result = creator.create_partitions(distribution)
          logical = result.partitions.with(type: ::Storage::PartitionType_LOGICAL)
          expect(logical).to contain_exactly an_object_with_fields(name: "/dev/sda5", size: 1.GiB)
        end
      end
    end

    context "when creating partitions within an existing extended one" do
      let(:scenario) { "space_22_extended" }
      let(:distribution) do
        space_dist(disk_spaces.first => vols_list(root_vol, home_vol))
      end

      before do
        allow(distribution.spaces.first).to receive(:partition_type).and_return :extended
      end

      it "reuses the extended partition" do
        result = creator.create_partitions(distribution)
        extended = result.partitions.with(type: ::Storage::PartitionType_EXTENDED)
        expect(extended).to contain_exactly an_object_with_fields(name: "/dev/sda4", size: 22.GiB)
      end

      it "creates all the partitions as logical" do
        result = creator.create_partitions(distribution)
        logical = result.partitions.with(type: ::Storage::PartitionType_LOGICAL)
        expect(logical).to contain_exactly(
          an_object_with_fields(name: "/dev/sda5", size: 1.GiB),
          an_object_with_fields(name: "/dev/sda6", size: 1.GiB)
        )
      end
    end
  end
end
