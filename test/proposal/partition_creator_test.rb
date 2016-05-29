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

    let(:settings) do
      settings = Yast::Storage::Proposal::Settings.new
      settings.candidate_devices = ["/dev/sda"]
      settings.root_device = "/dev/sda"
      settings
    end
    let(:scenario) { "empty_hard_disk_50GiB" }

    let(:root_volume) { Yast::Storage::PlannedVolume.new("/", ::Storage::FsType_EXT4) }
    let(:home_volume) { Yast::Storage::PlannedVolume.new("/home", ::Storage::FsType_EXT4) }
    let(:swap_volume) { Yast::Storage::PlannedVolume.new("swap", ::Storage::FsType_EXT4) }
    let(:volumes) { Yast::Storage::PlannedVolumesList.new([root_volume, home_volume, swap_volume]) }

    subject(:creator) { described_class.new(fake_devicegraph, settings) }

    context "when the exact space is available" do
      before do
        root_volume.desired = 20.GiB
        home_volume.desired = 20.GiB
        swap_volume.desired = 10.GiB
      end

      it "creates partitions matching the volume sizes" do
        result = creator.create_partitions(volumes)
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(mountpoint: "/", size: 20.GiB),
          an_object_with_fields(mountpoint: "/home", size: 20.GiB),
          an_object_with_fields(mountpoint: "swap", size: 10.GiB)
        )
      end
    end

    context "when some extra space is available" do
      before do
        root_volume.desired = 20.GiB
        root_volume.weight = 1
        home_volume.desired = 20.GiB
        home_volume.weight = 2
        swap_volume.desired = 1.GiB
        swap_volume.max_size = 1.GiB
      end

      it "distributes the extra space" do
        result = creator.create_partitions(volumes)
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(mountpoint: "/", size: 23.GiB),
          an_object_with_fields(mountpoint: "/home", size: 26.GiB),
          an_object_with_fields(mountpoint: "swap", size: 1.GiB)
        )
      end
    end

    context "when there is no enough space to allocate start of all partitions" do
      before do
        root_volume.desired = 25.GiB
        home_volume.desired = 25.GiB
        swap_volume.desired = 10.GiB
      end

      it "raises an error" do
        expect { creator.create_partitions(volumes) }
          .to raise_error Yast::Storage::Proposal::Error
      end
    end

    context "when some volume is marked as 'reuse'" do
      before do
        root_volume.desired = 20.GiB
        home_volume.desired = 20.GiB
        swap_volume.reuse = "/dev/something"
        home_volume.weight = root_volume.weight = swap_volume.weight = 1
      end

      it "does not create the reused volumes" do
        result = creator.create_partitions(volumes)
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(mountpoint: "/"),
          an_object_with_fields(mountpoint: "/home")
        )
      end

      it "distributes extra space between the new (not reused) volumes" do
        result = creator.create_partitions(volumes)
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(size: 25.GiB),
          an_object_with_fields(size: 25.GiB)
        )
      end
    end

    context "when a ms-dos type partition is used" do
      before do
        root_volume.desired = 10.GiB
        home_volume.desired = 10.GiB
        swap_volume.desired = 2.GiB
      end

      context "when the only available space is in an extended partition" do
        let(:scenario) { "space_22_extended" }

        it "creates all partitions as logical" do
          result = creator.create_partitions(volumes)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda1"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda2"),
            an_object_with_fields(type: ::Storage::PartitionType_EXTENDED, name: "/dev/sda4"),
            an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda5"),
            an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda6"),
            an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda7")
          )
        end
      end

      context "when the only available space is completely unassigned" do
        let(:scenario) { "space_22" }

        it "creates primary/extended/logical partitions as needed" do
          result = creator.create_partitions(volumes)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda1"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda2"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda3"),
            an_object_with_fields(type: ::Storage::PartitionType_EXTENDED, name: "/dev/sda4"),
            an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda5"),
            an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda6")
          )
        end
      end
    end
  end
end
