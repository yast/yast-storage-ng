#!/usr/bin/env rspec
#
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2storage/planned"

describe Y2Storage::Planned::Partition do
  using Y2Storage::Refinements::SizeCasts

  subject(:partition) { described_class.new(mount_point) }
  let(:mount_point) { "/" }

  # Only basic cases are tested here. More exhaustive tests can be found in tests
  # for Y2Storage::MatchVolumeSpec
  describe "match_volume?" do
    let(:volume) { Y2Storage::VolumeSpecification.new({}) }

    before do
      partition.partition_id = partition_id
      partition.filesystem_type = filesystem_type
      partition.min_size = min_size

      volume.mount_point = volume_mount_point
      volume.partition_id = volume_partition_id
      volume.fs_types = volume_fs_types
      volume.min_size = volume_min_size
    end

    let(:volume_mount_point) { "/boot" }
    let(:volume_partition_id) { Y2Storage::PartitionId::ESP }
    let(:volume_fs_types) { [Y2Storage::Filesystems::Type::EXT2] }
    let(:volume_min_size) { 1.GiB }

    context "when the planned partition has the same values" do
      let(:mount_point) { volume_mount_point }
      let(:partition_id) { volume_partition_id }
      let(:filesystem_type) { volume_fs_types.first }
      let(:min_size) { volume_min_size }

      it "returns true" do
        expect(partition.match_volume?(volume)).to eq(true)
      end
    end

    context "when the planned partition does not have the same values" do
      let(:mount_point) { "/boot/efi" }
      let(:partition_id) { Y2Storage::PartitionId::LINUX }
      let(:filesystem_type) { Y2Storage::Filesystems::Type::VFAT }
      let(:min_size) { 2.GiB }

      it "returns false" do
        expect(partition.match_volume?(volume)).to eq(false)
      end
    end
  end

  describe "#component?" do
    context "when it is not used as PV or RAID member" do
      it "returns false" do
        expect(partition.component?).to eq(false)
      end
    end

    context "when it is planned to be used as a PV" do
      before do
        partition.lvm_volume_group_name = "system"
      end

      it "returns true" do
        expect(partition.component?).to eq(true)
      end
    end

    context "when it is planned to be used as RAID member" do
      before do
        partition.raid_name = "system"
      end

      it "returns true" do
        expect(partition.component?).to eq(true)
      end
    end
  end
end
