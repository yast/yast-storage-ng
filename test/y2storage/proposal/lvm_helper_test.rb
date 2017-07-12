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
  let(:volumes_list) { volumes }
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
      let(:volumes) { [planned_lv(mount_point: "/1", type: :ext4, min: desired)] }

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
      let(:volumes) { [planned_lv(mount_point: "/1", type: :ext4, min: 1.GiB, max: max)] }

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
      let(:volumes) { [planned_lv(mount_point: "/1", type: :ext4, min: 10.GiB)] }

      it "returns an empty array" do
        expect(helper.reusable_volume_groups(fake_devicegraph)).to eq []
      end
    end

    context "if no volume group is big enough" do
      let(:scenario) { "lvm-four-vgs" }
      let(:volumes) { [planned_lv(mount_point: "/1", type: :ext4, min: 40.GiB)] }

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
      let(:volumes) { [planned_lv(mount_point: "/1", type: :ext4, min: 8.GiB)] }

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
        planned_lv(mount_point: "/1", type: :ext4, logical_volume_name: "one", min: 10.GiB),
        planned_lv(mount_point: "/2", type: :ext4, logical_volume_name: "two", min: 5.GiB)
      ]
    end
    let(:lvm_creator) { Y2Storage::Proposal::LvmCreator.new(fake_devicegraph) }
    let(:pv_partitions) { ["/dev/sda1", "/dev/sda3"] }
    let(:creator_result) { double("Y2Storage::Proposal::CreatorResult", devicegraph: nil) }

    before do
      allow(Y2Storage::Proposal::LvmCreator).to receive(:new).and_return(lvm_creator)
    end

    it "creates a new volume group" do
      devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
      vgs = devicegraph.lvm_vgs
      expect(vgs.size).to eq 2
      expect(vgs.map(&:vg_name)).to include "system"
    end

    it "adds the new physical volumes to the new volume group" do
      expect(lvm_creator).to receive(:create_volumes)
        .with(Y2Storage::Planned::LvmVg, pv_partitions).and_return creator_result
      helper.create_volumes(fake_devicegraph, pv_partitions)
    end

    it "adds the logical volumes to the volume group to be created" do
      expect(lvm_creator).to receive(:create_volumes) do |lvm_vg, _pv_partitions|
        expect(lvm_vg.lvs).to eq(volumes)
      end.and_return creator_result
      helper.create_volumes(fake_devicegraph, pv_partitions)
    end

    context "if an existing volume group is reused" do
      let(:reused_vg) { fake_devicegraph.lvm_vgs.first }

      before do
        helper.reused_volume_group = reused_vg
      end

      it "reuses the given volume group" do
        expect(lvm_creator).to receive(:create_volumes) do |lvm_vg, _pv_partitions|
          expect(lvm_vg.reuse).to eq(reused_vg.vg_name)
        end.and_return creator_result
        helper.create_volumes(fake_devicegraph, pv_partitions)
      end
    end

    context "when the volume group is empty" do
      let(:volumes) { [] }

      it "does not create it" do
        expect(Y2Storage::Proposal::LvmCreator).to_not receive(:new)
        helper.create_volumes(fake_devicegraph, pv_partitions)
      end

      it "returns a copy of the original devicegraph" do
        devicegraph = helper.create_volumes(fake_devicegraph, pv_partitions)
        expect(devicegraph).to_not be(fake_devicegraph)
      end
    end
  end
end
