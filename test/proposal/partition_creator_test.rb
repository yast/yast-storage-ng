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
    let(:target_size) { :desired }

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
        result = creator.create_partitions(volumes, target_size)
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
        result = creator.create_partitions(volumes, target_size)
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
        expect { creator.create_partitions(volumes, target_size) }
          .to raise_error Yast::Storage::Proposal::Error
      end
    end
  end
end
