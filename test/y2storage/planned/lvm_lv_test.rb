#!/usr/bin/env rspec
#
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
require "y2storage/planned"

describe Y2Storage::Planned::LvmLv do
  using Y2Storage::Refinements::SizeCasts

  subject(:lvm_lv) { described_class.new(mount_point) }

  let(:mount_point) { "/" }

  let(:volume_group) do
    instance_double(Y2Storage::LvmVg, size: 30.GiB, extent_size: 4.MiB)
  end

  describe "#initialize" do
    context "when creating a planned lv for a given mount point" do
      context "and the mount point is '/'" do
        let(:mount_point) { "/" }

        it "sets lv name to 'root'" do
          expect(subject.logical_volume_name).to eq("root")
        end
      end

      context "and the mount point is not '/'" do
        let(:mount_point) { "/var/lib/docker" }

        it "sets lv name based on mount point" do
          expect(subject.logical_volume_name).to eq("var_lib_docker")
        end
      end
    end

    context "when creating a planned lv without mount point" do
      let(:mount_point) { nil }

      it "does not set lv name" do
        expect(subject.logical_volume_name).to be_nil
      end
    end
  end

  describe "#size_in" do
    let(:lv_size) { 10.GiB }

    before do
      lvm_lv.size = lv_size
    end

    it "returns the logical volume size" do
      expect(lvm_lv.size_in(volume_group)).to eq(lv_size)
    end

    context "when size is a percentage" do
      before do
        lvm_lv.percent_size = 50
      end

      it "returns the size based on the volume group size" do
        expect(lvm_lv.size_in(volume_group)).to eq(15.GiB)
      end
    end
  end

  # Only basic cases are tested here. More exhaustive tests can be found in tests
  # for Y2Storage::MatchVolumeSpec
  describe "match_volume?" do
    let(:volume) { Y2Storage::VolumeSpecification.new({}) }

    before do
      lvm_lv.min_size = min_size
      lvm_lv.filesystem_type = filesystem_type

      volume.mount_point = volume_mount_point
      volume.partition_id = volume_partition_id
      volume.fs_types = volume_fs_types
      volume.min_size = volume_min_size
    end

    let(:volume_mount_point) { "/boot" }
    let(:volume_partition_id) { nil }
    let(:volume_fs_types) { [Y2Storage::Filesystems::Type::EXT2] }
    let(:volume_min_size) { 1.GiB }

    context "when the planned lv has the same values" do
      let(:mount_point) { volume_mount_point }
      let(:filesystem_type) { volume_fs_types.first }
      let(:min_size) { volume_min_size }

      it "returns true" do
        expect(lvm_lv.match_volume?(volume)).to eq(true)
      end

      context "but the volume requires a specific partition id" do
        let(:volume_partition_id) { Y2Storage::PartitionId::ESP }

        it "returns false" do
          expect(lvm_lv.match_volume?(volume)).to eq(false)
        end
      end
    end

    context "when the planned lv does not have the same values" do
      let(:mount_point) { "/boot/efi" }
      let(:filesystem_type) { Y2Storage::Filesystems::Type::VFAT }
      let(:min_size) { 2.GiB }

      it "returns false" do
        expect(lvm_lv.match_volume?(volume)).to eq(false)
      end
    end
  end

  describe "#add_thin_lv" do
    subject(:lvm_lv) { planned_lv(lv_type: Y2Storage::LvType::THIN_POOL) }
    let(:thin_lv) { planned_lv(lv_type: Y2Storage::LvType::THIN) }

    it "adds a thin lv to the thin pool lv" do
      lvm_lv.add_thin_lv(thin_lv)
      expect(lvm_lv.thin_lvs).to include(thin_lv)
    end

    it "points the thin lv the its pool" do
      lvm_lv.add_thin_lv(thin_lv)
      expect(thin_lv.thin_pool).to eq(lvm_lv)
    end
  end
end
