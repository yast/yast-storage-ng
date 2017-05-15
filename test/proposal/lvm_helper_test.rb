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

  before do
    fake_scenario(scenario)
  end

  subject(:helper) { described_class.new(volumes_list, encryption_password: enc_password) }
  let(:volumes_list) { Y2Storage::PlannedVolumesList.new(volumes) }
  let(:volumes) { [] }
  let(:enc_password) { nil }

  describe "#missing_space" do
    let(:scenario) { "lvm-big-pe" }
    let(:vg_big_pe) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }

    context "if no LVM volumes are planned" do
      let(:volumes) { [] }

      it "returns zero" do
        expect(helper.missing_space).to be_zero
      end
    end

    context "if some LVM volumes are planned" do
      let(:volumes) { [planned_vol(mount_point: "/1", type: :ext4, min: desired)] }

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
          missing = desired - vg_big_pe.size
          # Extent size of vg_big_pe is 64 MiB
          rounding = 62.MiB
          expect(helper.missing_space).to eq(missing + rounding)
        end
      end
    end
  end

  describe "#max_extra_space" do
    let(:scenario) { "lvm-big-pe" }
    let(:vg_big_pe) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }

    context "if no LVM volumes are planned" do
      let(:volumes) { [] }

      it "returns zero" do
        expect(helper.max_extra_space).to be_zero
      end
    end

    context "if some LVM volumes are planned" do
      let(:volumes) { [planned_vol(mount_point: "/1", type: :ext4, min: 1.GiB, max: max)] }

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
          extra = max - vg_big_pe.size
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
      let(:volumes) { [planned_vol(mount_point: "/1", type: :ext4, min: 10.GiB)] }

      it "returns an empty array" do
        expect(helper.reusable_volume_groups(fake_devicegraph)).to eq []
      end
    end

    context "if no volume group is big enough" do
      let(:scenario) { "lvm-four-vgs" }
      let(:volumes) { [planned_vol(mount_point: "/1", type: :ext4, min: 40.GiB)] }

      it "returns all the volume groups sorted by descending size" do
        result = helper.reusable_volume_groups(fake_devicegraph)
        expect(result.map(&:vg_name)).to eq ["vg30", "vg10", "vg6", "vg4"]
      end

      context "and encryption is being used" do
        let(:enc_password) { "12345678" }

        it "returns an empty array" do
          expect(helper.reusable_volume_groups(fake_devicegraph)).to eq []
        end
      end
    end

    context "if some volume groups are big enough" do
      let(:scenario) { "lvm-four-vgs" }
      let(:volumes) { [planned_vol(mount_point: "/1", type: :ext4, min: 8.GiB)] }

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

      context "and encryption is being used" do
        let(:enc_password) { "12345678" }

        it "returns an empty array" do
          expect(helper.reusable_volume_groups(fake_devicegraph)).to eq []
        end
      end
    end
  end

  describe "#encrypt?" do
    let(:scenario) { "windows-pc" }

    context "if the encryption password was not initialized" do
      let(:enc_password) { nil }

      it "returns false" do
        expect(helper.encrypt?).to eq false
      end
    end

    context "if the encryption password was set" do
      let(:enc_password) { "Sec3t!" }

      it "returns true" do
        expect(helper.encrypt?).to eq true
      end
    end
  end

  describe "#create_volumes" do
    let(:scenario) { "lvm-new-pvs" }
    let(:volumes) do
      [
        planned_vol(mount_point: "/1", type: :ext4, logical_volume_name: "one", min: 10.GiB),
        planned_vol(mount_point: "/2", type: :ext4, logical_volume_name: "two", min: 5.GiB)
      ]
    end
    let(:pv_partitions) { ["/dev/sda1", "/dev/sda3"] }
    let(:ext4) { Y2Storage::Filesystems::Type::EXT4 }

    before do
      helper.reused_volume_group = reused_vg
    end

    context "if no volume group is reused" do
      let(:reused_vg) { nil }

      it "creates a new volume group" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        vgs = devicegraph.lvm_vgs
        expect(vgs.size).to eq 2
        expect(vgs.map(&:vg_name)).to include "system"
      end

      it "adds the new physical volumes to the new volume group" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        new_vg = devicegraph.lvm_vgs.detect { |vg| vg.vg_name == "system" }
        pv_names = new_vg.lvm_pvs.map { |pv| pv.blk_device.name }
        expect(pv_names.sort).to eq pv_partitions.sort
      end

      it "creates a new logical volume for each planned volume" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        new_vg = devicegraph.lvm_vgs.detect { |vg| vg.vg_name == "system" }
        expect(new_vg.lvm_lvs).to contain_exactly(
          an_object_having_attributes(
            filesystem_mountpoint: "/1",
            lv_name:               "one",
            filesystem_type:       ext4
          ),
          an_object_having_attributes(
            filesystem_mountpoint: "/2",
            lv_name:               "two",
            filesystem_type:       ext4
          )
        )
      end

      context "and encryption is used" do
        let(:scenario) { "lvm-new-encrypted-pvs" }
        let(:enc_password) { "SomePassphrase" }

        it "uses the encrypted devices to create the physical volumes" do
          devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
          new_vg = devicegraph.lvm_vgs.detect { |vg| vg.vg_name == "system" }
          pv_devices = new_vg.lvm_pvs.map(&:blk_device)

          pv_devices.each do |device|
            expect(device.is?(:encryption)).to eq true
          end
          part_names = pv_devices.map { |d| d.blk_device.plain_device.name }
          expect(part_names.sort).to eq pv_partitions.sort
        end
      end
    end

    context "if an existing volume group is reused" do
      let(:reused_vg) { fake_devicegraph.lvm_vgs.first }

      it "creates no additional volume group" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        vgs = devicegraph.lvm_vgs
        expect(vgs.size).to eq 1
      end

      it "adds the new physical volumes to the existing volume group" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        reused_vg = devicegraph.lvm_vgs.detect { |vg| vg.vg_name == "vg0" }
        pv_names = reused_vg.lvm_pvs.map { |pv| pv.blk_device.name }
        expect(pv_names.sort).to eq ["/dev/sda1", "/dev/sda2", "/dev/sda3"]
      end

      it "creates a new logical volume for each planned volume" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        reused_vg = devicegraph.lvm_vgs.first
        one = reused_vg.lvm_lvs.detect { |lv| lv.lv_name == "one" }
        expect(one).to have_attributes(filesystem_mountpoint: "/1", filesystem_type: ext4)
        two = reused_vg.lvm_lvs.detect { |lv| lv.lv_name == "two" }
        expect(two).to have_attributes(filesystem_mountpoint: "/2", filesystem_type: ext4)
      end

      it "does not delete existing LVs if there is enough free space" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        reused_vg = devicegraph.lvm_vgs.first
        lv_names = reused_vg.lvm_lvs.map { |lv| lv.lv_name }
        expect(lv_names).to include("lv1", "lv2")
      end

      it "deletes existing LVs as needed to make space" do
        volumes << planned_vol(type: :ext4, logical_volume_name: "three", min: 20.GiB)

        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        reused_vg = devicegraph.lvm_vgs.first
        lv_names = reused_vg.lvm_lvs.map(&:lv_name)
        expect(lv_names).to_not include "lv2"
        expect(lv_names).to include "lv1"
      end
    end

    context "if the exact space is available" do
      let(:reused_vg) { nil }

      before do
        volumes.first.min_size = 15.GiB - 4.MiB
        volumes.last.min_size = 5.GiB - 4.MiB
      end

      it "creates partitions matching the volume sizes" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        lvs = devicegraph.lvm_lvs.select { |lv| lv.lvm_vg.vg_name == "system" }

        expect(lvs).to contain_exactly(
          an_object_having_attributes(lv_name: "one", size: 15.GiB - 4.MiB),
          an_object_having_attributes(lv_name: "two", size: 5.GiB - 4.MiB)
        )
      end
    end

    context "if some extra space is available" do
      let(:reused_vg) { nil }

      before do
        one = volumes.first
        two = volumes.last
        volumes << planned_vol(logical_volume_name: "three", min: 1.GiB, max: 2.GiB, weight: 1)

        one.min_size = 5.GiB
        one.weight = 2
        two.min_size = 7.GiB
        two.weight = 1
      end

      it "distributes the extra space according to weights" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        lvs = devicegraph.lvm_lvs.select { |lv| lv.lvm_vg.vg_name == "system" }

        expect(lvs).to contain_exactly(
          an_object_having_attributes(lv_name: "one", size: 9.GiB - 4.MiB),
          an_object_having_attributes(lv_name: "two", size: 9.GiB - 4.MiB),
          an_object_having_attributes(lv_name: "three", size: 2.GiB)
        )
      end

      it "does not distribute more space than available" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        system_vg = devicegraph.lvm_vgs.detect { |vg| vg.vg_name == "system" }
        lvs = system_vg.lvm_lvs
        lvs_size = lvs.reduce(Y2Storage::DiskSize.zero) { |sum, lv| sum + lv.size }

        expect(system_vg.size).to eq lvs_size
      end
    end

    context "when the volume group name is already taken" do
      let(:scenario) { "lvm-name-conflicts" }
      let(:reused_vg) { nil }
      let(:pv_partitions) { ["/dev/sda2"] }

      it "chooses a new name adding a number" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        vg_names = devicegraph.lvm_vgs.map(&:vg_name)
        expect(vg_names).to contain_exactly("system", "system0")
      end
    end

    context "when a logical volume name is already taken" do
      let(:scenario) { "lvm-name-conflicts" }
      let(:reused_vg) { fake_devicegraph.lvm_vgs.first }
      let(:pv_partitions) { [] }

      it "chooses a new name adding a number" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        lv_names = devicegraph.lvm_lvs.map(&:lv_name)
        expect(lv_names).to include("one", "one0", "one1", "one2")
      end
    end
  end
end
