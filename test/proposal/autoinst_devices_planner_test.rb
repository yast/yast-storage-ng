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
require "y2storage/proposal/autoinst_devices_planner"

describe Y2Storage::Proposal::AutoinstDevicesPlanner do
  using Y2Storage::Refinements::SizeCasts

  subject(:planner) { described_class.new(fake_devicegraph) }

  let(:scenario) { "windows-linux-free-pc" }
  let(:drives_map) { Y2Storage::Proposal::AutoinstDrivesMap.new(fake_devicegraph, partitioning) }
  let(:boot_checker) { instance_double(Y2Storage::BootRequirementsChecker, needed_partitions: []) }

  let(:partitioning_array) do
    [{ "device" => "/dev/sda", "partitions" => [root_spec] }]
  end
  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(partitioning_array)
  end

  let(:root_spec) { { "mount" => "/", "filesystem" => "ext4" } }
  let(:lvm_group) { "vg0" }

  before do
    allow(Y2Storage::BootRequirementsChecker).to receive(:new)
      .and_return(boot_checker)
    fake_scenario(scenario)
  end

  describe "#planned_devices" do
    context "when a boot partition is required" do
      let(:boot) { Y2Storage::Planned::Partition.new("/boot", Y2Storage::Filesystems::Type::EXT4) }

      it "adds the boot partition" do
        expect(Y2Storage::BootRequirementsChecker).to receive(:new)
          .and_return(boot_checker)
        expect(boot_checker).to receive(:needed_partitions).and_return([boot])
        expect(planner.planned_devices(drives_map).map(&:mount_point)).to include("/boot")
      end
    end

    context "reusing partitions" do
      context "when a partition number is specified" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => "ext4", "partition_nr" => 3 }
        end

        it "reuses the partition with that number" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse).to eq("/dev/sda3")
        end
      end

      context "when a partition label is specified" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => "ext4", "label" => "root" }
        end

        it "reuses the partition with that label" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse).to eq("/dev/sda3")
        end
      end
    end

    context "specifying size" do
      using Y2Storage::Refinements::SizeCasts

      let(:root_spec) do
        { "mount" => "/", "filesystem" => "ext4", "size" => size }
      end

      context "when a number+unit is given" do
        let(:disk_size) { 5.GiB }
        let(:size) { "5GB" }

        it "sets the size according to that number and using legacy_units" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(disk_size)
          expect(root.max_size).to eq(disk_size)
        end
      end

      context "when a percentage is given" do
        let(:disk_size) { 250.GiB }
        let(:size) { "50%" }

        it "sets the size according to the percentage" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(disk_size)
          expect(root.max_size).to eq(disk_size)
        end
      end

      context "when 'max' is given" do
        let(:size) { "max" }

        it "sets the size to 'unlimited'" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(1.MiB)
          expect(root.max_size).to eq(Y2Storage::DiskSize.unlimited)
        end
      end
    end

    context "specifying filesystem" do
      let(:partitioning_array) do
        [{ "device" => "/dev/sda", "use" => "all", "partitions" => [root_spec, home_spec] }]
      end

      let(:home_spec) do
        { "mount" => "/home", "filesystem" => "xfs" }
      end

      it "sets the filesystem" do
        devices = planner.planned_devices(drives_map)
        root = devices.find { |d| d.mount_point == "/" }
        home = devices.find { |d| d.mount_point == "/home" }
        expect(root.filesystem_type).to eq(Y2Storage::Filesystems::Type::EXT4)
        expect(home.filesystem_type).to eq(Y2Storage::Filesystems::Type::XFS)
      end
    end

    context "specifying crypted partitions" do
      let(:root_spec) do
        { "mount" => "/", "filesystem" => "ext4", "crypt_fs" => true, "crypt_key" => "secret" }
      end

      it "sets the encryption password" do
        devices = planner.planned_devices(drives_map)
        root = devices.find { |d| d.mount_point == "/" }
        expect(root.encryption_password).to eq("secret")
      end
    end

    context "using LVM" do
      let(:partitioning_array) do
        [
          { "device" => "/dev/sda", "partitions" => [pv] }, vg
        ]
      end

      let(:vg) do
        { "device" => "/dev/#{lvm_group}", "partitions" => [root_spec], "type" => :CT_LVM }
      end

      let(:pv) do
        { "create" => true, "lvm_group" => lvm_group, "size" => "max", "type" => :CT_LVM }
      end

      let(:lvm_spec) do
        { "is_lvm_vg" => true, "partitions" => [root_spec] }
      end

      let(:root_spec) do
        {
          "mount" => "/", "filesystem" => "ext4", "lv_name" => "root", "size" => "20G",
          "label" => "rootfs"
        }
      end

      it "returns volume group and logical volumes" do
        pv, vg = planner.planned_devices(drives_map)
        expect(pv).to be_a(Y2Storage::Planned::Partition)
        expect(vg).to be_a(Y2Storage::Planned::LvmVg)
        expect(vg).to have_attributes(
          "volume_group_name" => lvm_group,
          "reuse"             => nil
        )
        expect(vg.lvs).to contain_exactly(
          an_object_having_attributes(
            "logical_volume_name" => "root",
            "mount_point"         => "/",
            "reuse"               => nil,
            "min_size"            => 20.GiB,
            "max_size"            => 20.GiB,
            "label"               => "rootfs"
          )
        )
      end

      context "specifying the size with percentages" do
        let(:root_spec) do
          { "mount" => "/", "filesystem" => "ext4", "lv_name" => "root", "size" => "50%" }
        end

        it "sets the 'percent_size' value" do
          _pv, vg = planner.planned_devices(drives_map)
          root_lv = vg.lvs.first
          expect(root_lv).to have_attributes("percent_size" => 50)
        end
      end

      context "reusing logical volumes" do
        let(:scenario) { "lvm-two-vgs" }

        let(:root_spec) do
          {
            "create" => false, "mount" => "/", "filesystem" => "ext4", "lv_name" => "lv1",
            "size" => "20G", "label" => "rootfs"
          }
        end

        it "sets the reuse attribute of the volume group" do
          _pv, vg = planner.planned_devices(drives_map)
          expect(vg.reuse).to eq(lvm_group)
          expect(vg.make_space_policy).to eq(:remove)
        end

        it "sets the reuse attribute of logical volumes" do
          _pv, vg = planner.planned_devices(drives_map)
          expect(vg.reuse).to eq(lvm_group)
          expect(vg.lvs).to contain_exactly(
            an_object_having_attributes(
              "logical_volume_name" => "lv1",
              "reuse"               => "/dev/vg0/lv1"
            )
          )
        end
      end

      context "reusing logical volumes by label" do
        let(:scenario) { "lvm-two-vgs" }

        let(:root_spec) do
          {
            "create" => false, "mount" => "/", "filesystem" => "ext4",
            "size" => "20G", "label" => "rootfs"
          }
        end

        it "sets the reuse attribute of logical volumes" do
          _pv, vg = planner.planned_devices(drives_map)
          expect(vg.reuse).to eq(lvm_group)
          expect(vg.lvs).to contain_exactly(
            an_object_having_attributes(
              "logical_volume_name" => "lv2",
              "reuse"               => "/dev/vg0/lv2"
            )
          )
        end
      end

      context "when unknown logical volumes are required to be kept" do
        let(:scenario) { "lvm-two-vgs" }

        let(:vg) do
          {
            "device" => "/dev/#{lvm_group}", "partitions" => [root_spec], "type" => :CT_LVM,
            "keep_unknown_lv" => true
          }
        end

        it "sets the reuse attribute of the volume group" do
          _pv, vg = planner.planned_devices(drives_map)
          expect(vg).to have_attributes(
            "volume_group_name" => lvm_group,
            "reuse"             => lvm_group,
            "make_space_policy" => :keep
          )
        end
      end

      context "when trying to reuse a logical volume which is in another volume group" do
        let(:lvm_group) { "vg1" }
        let(:scenario) { "lvm-two-vgs" }

        let(:root_spec) do
          {
            "create" => false, "mount" => "/", "filesystem" => "ext4", "lv_name" => "lv2",
            "size" => "20G", "label" => "rootfs"
          }
        end

        it "does not set the reuse attribute of the logical volume" do
          _pv, vg = planner.planned_devices(drives_map)
          expect(vg.lvs).to contain_exactly(
            an_object_having_attributes(
              "logical_volume_name" => "lv2",
              "reuse"               => nil
            )
          )
        end
      end
    end
  end
end
