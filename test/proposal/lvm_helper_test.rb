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
require "y2storage"

describe Y2Storage::Proposal::LvmHelper do
  using Y2Storage::Refinements::SizeCasts
  using Y2Storage::Refinements::DevicegraphLists

  before do
    fake_scenario(scenario)
  end

  subject(:helper) { described_class.new(volumes_list) }
  let(:volumes_list) { Y2Storage::PlannedVolumesList.new(volumes, target: :desired) }
  let(:volumes) { [] }

  describe "#missing_space" do
    let(:scenario) { "lvm-big-pe" }
    let(:vg_big_pe) { Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }

    context "if no LVM volumes are planned" do
      let(:volumes) { [] }

      it "returns zero" do
        expect(helper.missing_space).to be_zero
      end
    end

    context "if some LVM volumes are planned" do
      let(:volumes) { [planned_vol(mount_point: "/1", type: :ext4, desired: desired)] }

      before do
        helper.reused_volume_group = reused_vg
      end

      context "and no volume group is being reused" do
        let(:reused_vg) { nil }
        let(:desired) { 10.GiB - 2.MiB }

        it "returns the target size rounded up to the default extent size" do
          expect(helper.missing_space).to eq 10.GiB
        end
      end

      context "and a big-enough volume group is being reused" do
        let(:reused_vg) { vg_big_pe }
        let(:desired) { 10.GiB }

        it "returns zero" do
          helper.reused_volume_group = vg_big_pe
          expect(helper.missing_space).to be_zero
        end
      end

      context "and a volume group that needs to be extended is being reused" do
        let(:reused_vg) { vg_big_pe }
        let(:desired) { 20.GiB + 2.MiB }

        it "returns the missing size rounded up to the VG extent size" do
          missing = Y2Storage::DiskSize.new(desired.to_i - vg_big_pe.size)
          # Extent size of vg_big_pe is 64 MiB
          rounding = 62.MiB
          expect(helper.missing_space).to eq(missing + rounding)
        end
      end
    end
  end

  describe "#missing_space" do
    let(:scenario) { "lvm-big-pe" }
    let(:vg_big_pe) { Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }

    context "if no LVM volumes are planned" do
      let(:volumes) { [] }

      it "returns zero" do
        expect(helper.max_extra_space).to be_zero
      end
    end

    context "if some LVM volumes are planned" do
      let(:volumes) { [planned_vol(mount_point: "/1", type: :ext4, desired: 1.GiB, max: max)] }

      before do
        helper.reused_volume_group = reused_vg
      end

      context "and the max size is unlimited" do
        let(:reused_vg) { nil }
        let(:unlimited) { Y2Storage::DiskSize.unlimited }
        let(:max) { unlimited }

        it "returns unlimited" do
          expect(helper.max_extra_space).to eq unlimited
        end
      end

      context "and no volume group is being reused" do
        let(:reused_vg) { nil }
        let(:max) { 30.GiB - 1.MiB }

        it "returns the max size rounded up to the default extent size" do
          expect(helper.max_extra_space).to eq 30.GiB
        end
      end

      context "and a volume group is being reused" do
        let(:reused_vg) { vg_big_pe }
        let(:max) { 30.GiB + 2.MiB }

        it "returns the extra size rounded up to the VG extent size" do
          extra = Y2Storage::DiskSize.new(max.to_i - vg_big_pe.size)
          # Extent size of vg_big_pe is 64 MiB
          rounding = 62.MiB
          expect(helper.max_extra_space).to eq(extra + rounding)
        end
      end
    end
  end

  describe "#reusable_volume_groups" do
    context "if there are no volume groups" do
      let(:scenario) { "windows-pc" }
      let(:volumes) { [planned_vol(mount_point: "/1", type: :ext4, desired: 10.GiB)] }

      it "returns an empty array" do
        expect(helper.reusable_volume_groups(fake_devicegraph)).to eq []
      end
    end

    context "if no volume group is big enough" do
      let(:scenario) { "lvm-four-vgs" }
      let(:volumes) { [planned_vol(mount_point: "/1", type: :ext4, desired: 40.GiB)] }

      it "returns all the volume groups sorted by descending size" do
        result = helper.reusable_volume_groups(fake_devicegraph)
        expect(result.map(&:vg_name)).to eq ["vg30", "vg10", "vg6", "vg4"]
      end
    end

    context "if some volume groups are big enough" do
      let(:scenario) { "lvm-four-vgs" }
      let(:volumes) { [planned_vol(mount_point: "/1", type: :ext4, desired: 8.GiB)] }

      it "returns all the volume groups" do
        result = helper.reusable_volume_groups(fake_devicegraph)
        expect(result.size).to eq 4
      end

      it "prefers big-enough groups sorted by ascending size" do
        result = helper.reusable_volume_groups(fake_devicegraph)
        expect(result[0].vg_name).to eq "vg10"
        expect(result[1].vg_name).to eq "vg30"
      end

      it "puts at the end all the groups that are not big enough, by descending size" do
        result = helper.reusable_volume_groups(fake_devicegraph)
        expect(result[2].vg_name).to eq "vg6"
        expect(result[3].vg_name).to eq "vg4"
      end
    end
  end

  describe "#create_volumes" do
    let(:scenario) { "lvm-new-pvs" }
    let(:volumes) do
      [
        planned_vol(mount_point: "/1", type: :ext4, logical_volume_name: "one", desired: 10.GiB),
        planned_vol(mount_point: "/2", type: :ext4, logical_volume_name: "two", desired: 5.GiB)
      ]
    end
    let(:pv_partitions) { ["/dev/sda1", "/dev/sda3"] }
    let(:ext4) { Storage::FsType_EXT4 }

    before do
      helper.reused_volume_group = reused_vg
    end

    context "if no volume group is reused" do
      let(:reused_vg) { nil }

      it "creates a new volume group" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        vgs = devicegraph.volume_groups
        expect(vgs.size).to eq 2
        expect(vgs.with(vg_name: "system").any?).to eq true
      end

      it "adds the new physical volumes to the new volume group" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        new_vg = devicegraph.volume_groups.with(vg_name: "system").first
        pv_names = new_vg.lvm_pvs.to_a.map { |pv| pv.blk_device.name }
        expect(pv_names.sort).to eq pv_partitions.sort
      end

      it "creates a new logical volume for each planned volume" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        new_vg = devicegraph.volume_groups.with(vg_name: "system").first
        expect(new_vg.lvm_lvs.to_a).to_not contain_exactly(
          an_object_with_fields(mountpoint: "/1", lv_name: "one", fs_type: :ext4),
          an_object_with_fields(mountpoint: "/2", lv_name: "two", fs_type: :ext4)
        )
      end
    end

    context "if an existing volume group is reused" do
      let(:reused_vg) { fake_devicegraph.volume_groups.first }

      it "creates no additional volume group" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        vgs = devicegraph.volume_groups
        expect(vgs.size).to eq 1
      end

      it "adds the new physical volumes to the existing volume group" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        reused_vg = devicegraph.volume_groups.with(vg_name: "vg0").first
        pv_names = reused_vg.lvm_pvs.to_a.map { |pv| pv.blk_device.name }
        expect(pv_names.sort).to eq ["/dev/sda1", "/dev/sda2", "/dev/sda3"]
      end

      it "creates a new logical volume for each planned volume" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        reused_vg = devicegraph.volume_groups.first
        one = reused_vg.lvm_lvs.to_a.detect { |lv| lv.lv_name == "one" }
        expect(one).to match_fields(mountpoint: "/1", fs_type: ext4)
        two = reused_vg.lvm_lvs.to_a.detect { |lv| lv.lv_name == "two" }
        expect(two).to match_fields(mountpoint: "/2", fs_type: ext4)
      end

      it "does not delete existing LVs if there is enough free space" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        reused_vg = devicegraph.volume_groups.first
        lv_names = reused_vg.lvm_lvs.to_a.map { |lv| lv.lv_name }
        expect(lv_names).to include("lv1", "lv2")
      end

      it "deletes existing LVs as needed to make space" do
        volumes << planned_vol(type: :ext4, logical_volume_name: "three", desired: 20.GiB)

        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        reused_vg = devicegraph.volume_groups.first
        lv_names = reused_vg.lvm_lvs.to_a.map { |lv| lv.lv_name }
        expect(lv_names).to_not include "lv2"
        expect(lv_names).to include "lv1"
      end
    end

    context "if the exact space is available" do
      let(:reused_vg) { nil }

      before do
        volumes.first.desired = 15.GiB - 4.MiB
        volumes.last.desired = 5.GiB - 4.MiB
      end

      it "creates partitions matching the volume sizes" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        lvs = devicegraph.volume_groups.with(vg_name: "system").lvm_lvs.to_a

        expect(lvs).to contain_exactly(
          an_object_with_fields(lv_name: "one", size: (15.GiB - 4.MiB).to_i),
          an_object_with_fields(lv_name: "two", size: (5.GiB - 4.MiB).to_i)
        )
      end
    end

    context "if some extra space is available" do
      let(:reused_vg) { nil }

      before do
        one = volumes.first
        two = volumes.last
        volumes << planned_vol(logical_volume_name: "three", desired: 1.GiB, max: 2.GiB, weight: 1)

        one.desired = 5.GiB
        one.weight = 2
        two.desired = 7.GiB
        two.weight = 1
      end

      it "distributes the extra space" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        lvs = devicegraph.volume_groups.with(vg_name: "system").lvm_lvs.to_a

        expect(lvs).to contain_exactly(
          an_object_with_fields(lv_name: "one", size: (9.GiB - 4.MiB).to_i),
          an_object_with_fields(lv_name: "two", size: 9.GiB.to_i),
          an_object_with_fields(lv_name: "three", size: 2.GiB.to_i)
        )
      end
    end

    context "when the volume group name is already taken" do
      let(:scenario) { "lvm-name-conflicts" }
      let(:reused_vg) { nil }
      let(:pv_partitions) { ["/dev/sda2"] }

      it "chooses a new name adding a number" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        vg_names = devicegraph.volume_groups.map(&:vg_name)
        expect(vg_names).to contain_exactly("system", "system0")
      end
    end

    context "when a logical volume name is already taken" do
      let(:scenario) { "lvm-name-conflicts" }
      let(:reused_vg) { fake_devicegraph.volume_groups.first }
      let(:pv_partitions) { [] }

      it "chooses a new name adding a number" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        lv_names = devicegraph.logical_volumes.map(&:lv_name)
        expect(lv_names).to include("one", "one0", "one1", "one2")
      end
    end
  end
end
