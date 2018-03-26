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
require "y2storage/proposal/autoinst_devices_creator"
require "y2storage/planned/partition"

describe Y2Storage::Proposal::AutoinstDevicesCreator do
  using Y2Storage::Refinements::SizeCasts

  let(:filesystem_type) { Y2Storage::Filesystems::Type::EXT4 }
  let(:mount_by_type) { Y2Storage::Filesystems::MountByType::PATH }
  let(:new_part) do
    Y2Storage::Planned::Partition.new("/home", filesystem_type).tap do |part|
      part.fstab_options = ["ro", "acl"]
      part.mkfs_options = "-b 2048"
      part.mount_by = mount_by_type
    end
  end
  let(:scenario) { "windows-linux-free-pc" }
  let(:reusable_part) do
    Y2Storage::Planned::Partition.new("/", filesystem_type).tap do |part|
      part.reuse_name = "/dev/sda3"
    end
  end

  before { fake_scenario(scenario) }

  subject(:creator) do
    described_class.new(Y2Storage::StorageManager.instance.probed)
  end

  describe "#populated_devicegraph" do
    it "returns AutoinstCreatorResult object" do
      result = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      expect(result).to be_a(Y2Storage::Proposal::AutoinstCreatorResult)
    end

    it "creates new partitions" do
      result = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      devicegraph = result.devicegraph
      _win, _swap, _root, home = devicegraph.partitions
      expect(home).to have_attributes(
        filesystem_type:       filesystem_type,
        filesystem_mountpoint: "/home"
      )
    end

    it "sets filesystem options" do
      result = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      devicegraph = result.devicegraph
      home = devicegraph.partitions.last
      fs = home.filesystem
      expect(fs.mkfs_options).to eq("-b 2048")
      expect(fs.mount_point.mount_options).to eq(["ro", "acl"])
      expect(fs.mount_point.mount_by).to eq(mount_by_type)
    end

    it "reuses partitions" do
      result = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      devicegraph = result.devicegraph
      root = devicegraph.partitions.find { |p| p.filesystem_mountpoint == "/" }
      expect(root).to have_attributes(
        filesystem_label: "root"
      )
    end

    it "ignores other disks" do
      result = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      devicegraph = result.devicegraph
      sdb = devicegraph.disks.find { |d| d.name == "/dev/sdb" }
      expect(sdb.partitions).to be_empty
    end

    context "when a partition is too big" do
      let(:new_part) do
        Y2Storage::Planned::Partition.new("/home", filesystem_type).tap do |part|
          part.min_size = 250.GiB
        end
      end

      it "shrinks the partition to make it fit into the disk" do
        result = creator.populated_devicegraph([new_part], "/dev/sda")
        devicegraph = result.devicegraph
        home = devicegraph.partitions.find { |p| p.filesystem_mountpoint == "/home" }
        expect(home.size).to eq(228.GiB - 1.MiB)
      end

      it "registers which devices were shrinked" do
        result = creator.populated_devicegraph([new_part], "/dev/sda")
        expect(result.shrinked_partitions.map(&:planned)).to eq([new_part])
      end
    end

    describe "using LVM" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:filesystem_type) { Y2Storage::Filesystems::Type::EXT4 }

      let(:pv) { planned_partition(lvm_volume_group_name: "vg0", min_size: 5.GiB) }

      let(:lv_root) { planned_lv(mount_point: "/", logical_volume_name: "lv_root") }

      let(:vg) { planned_vg(volume_group_name: "vg0", lvs: [lv_root]) }

      it "adds volume groups" do
        result = creator.populated_devicegraph([pv, vg], ["/dev/sda"])
        devicegraph = result.devicegraph
        vg = devicegraph.lvm_vgs.first
        expect(vg.lvm_pvs.map(&:blk_device).map(&:name)).to eq(["/dev/sda1"])
        expect(vg.vg_name).to eq("vg0")
        expect(vg.lvm_lvs.map(&:lv_name)).to eq(["lv_root"])
      end

      it "adds logical volumes" do
        result = creator.populated_devicegraph([pv, vg], ["/dev/sda"])
        devicegraph = result.devicegraph
        lv = devicegraph.lvm_lvs.first
        expect(lv.lv_name).to eq("lv_root")
        expect(lv.lvm_vg.vg_name).to eq("vg0")
      end

      context "when logical volume is too big" do
        let(:lv_root) do
          planned_lv(mount_point: "/", logical_volume_name: "lv_root", min_size: 10.GiB)
        end

        it "shrinks the logical volume to make it fit into the volume group" do
          result = creator.populated_devicegraph([pv, vg], ["/dev/sda"])
          devicegraph = result.devicegraph
          vg = devicegraph.lvm_vgs.first
          lv = vg.lvm_lvs.first
          expect(lv.size).to eq(vg.size)
        end

        it "registers which devices were shrinked" do
          result = creator.populated_devicegraph([pv, vg], ["/dev/sda"])
          expect(result.shrinked_lvs.map(&:planned)).to eq([lv_root])
        end
      end

      context "reusing a partition as physical volume" do
        let(:scenario) { "windows-linux-free-pc" }
        let(:pv) do
          planned_partition(
            lvm_volume_group_name: "vg0", reuse_name: "/dev/sda3"
          )
        end

        it "adds the physical volume to the volume group" do
          result = creator.populated_devicegraph([pv, vg], ["/dev/sda"])
          devicegraph = result.devicegraph
          vg = devicegraph.lvm_vgs.first
          pv = vg.lvm_pvs.first
          expect(pv).to_not be_nil
          expect(pv.blk_device.name).to eq("/dev/sda3")
        end
      end

      context "when creating more than one volume group" do
        let(:pv1) { planned_partition(lvm_volume_group_name: "vg1", min_size: 5.GiB) }

        let(:lv_srv) { planned_lv(mount_point: "/srv", logical_volume_name: "lv_srv") }
        let(:vg1) { planned_vg(volume_group_name: "vg1", lvs: [lv_root]) }

        it "creates all volume groups" do
          result = creator.populated_devicegraph([pv, pv1, vg, vg1], ["/dev/sda"])
          lvm_vgs = result.devicegraph.lvm_vgs
          expect(lvm_vgs.size).to eq(2)
        end
      end
    end

    describe "using RAID" do
      context "reusing a partition as a RAID member" do
        let(:part1) do
          planned_partition(disk: "/dev/sda", raid_name: "/dev/md0", reuse_name: "/dev/sda3")
        end

        let(:part2) do
          planned_partition(
            disk: "/dev/sdb", raid_name: "/dev/md0", min_size: 20.GiB, max_size: 20.GiB
          )
        end

        let(:md0) do
          planned_md(name: "/dev/md0", mount_point: "/")
        end

        it "adds the partition as a RAID member" do
          result = creator.populated_devicegraph([part1, part2, md0], ["/dev/sda", "/dev/sdb"])
          devicegraph = result.devicegraph
          md = devicegraph.md_raids.first
          expect(md.devices.size).to eq(2)
        end
      end
    end

    describe "resizing partitions" do
      let(:root) do
        Y2Storage::Planned::Partition.new("/", filesystem_type).tap do |part|
          part.reuse_name = "/dev/sda1"
          part.resize = true
          part.max_size = 200.GiB
        end
      end

      let(:home) do
        Y2Storage::Planned::Partition.new("/home", filesystem_type).tap do |part|
          part.reuse_name = "/dev/sda2"
          part.resize = true
          part.size = 52.GiB
        end
      end

      let(:resize_info) do
        {
          "/dev/sda1" => info_sda1,
          "/dev/sda2" => info_sda2
        }
      end

      let(:info_sda1) do
        instance_double(
          Y2Storage::ResizeInfo, min_size: 1.GiB, max_size: 250.GiB, resize_ok?: true,
          reasons: 0, reason_texts: []
        )
      end

      let(:info_sda2) do
        instance_double(
          Y2Storage::ResizeInfo, min_size: 1.GiB, max_size: 52.GiB, resize_ok?: true,
          reasons: 0, reason_texts: []
        )
      end

      before do
        allow_any_instance_of(Y2Storage::Partition).to receive(:detect_resize_info) do |part|
          resize_info[part.name]
        end
      end

      it "assigns sizes to each partition to resize" do
        result = creator.populated_devicegraph([home, root], "/dev/sda")
        devicegraph = result.devicegraph

        root = devicegraph.partitions.find { |p| p.filesystem_mountpoint == "/" }
        expect(root.size).to eq(200.GiB)

        home = devicegraph.partitions.find { |p| p.filesystem_mountpoint == "/home" }
        expect(home.size).to eq(52.GiB)
      end
    end

    describe "resizing logical volumes" do
      let(:scenario) { "lvm-two-vgs" }

      let(:pv) { planned_partition(reuse_name: "/dev/sda7") }

      let(:vg) do
        planned_vg(reuse_name: "vg0", lvs: [root, home], pvs: [pv])
      end

      let(:root) do
        planned_lv(mount_point: "/", reuse_name: "/dev/vg0/lv1", resize: true, max_size: 1.GiB)
      end

      let(:home) do
        planned_lv(mount_point: "/home", reuse_name: "/dev/vg0/lv2", resize: true, max_size: 3.GiB)
      end

      let(:resize_info) do
        {
          "/dev/vg0/lv1" => info_lv1,
          "/dev/vg0/lv2" => info_lv2
        }
      end

      let(:info_lv1) do
        instance_double(
          Y2Storage::ResizeInfo, min_size: 1.GiB, max_size: 250.GiB, resize_ok?: true,
          reasons: 0, reason_texts: []
        )
      end

      let(:info_lv2) do
        instance_double(
          Y2Storage::ResizeInfo, min_size: 1.GiB, max_size: 52.GiB, resize_ok?: true,
          reasons: 0, reason_texts: []
        )
      end

      before do
        allow_any_instance_of(Y2Storage::LvmLv).to receive(:detect_resize_info) do |lv|
          resize_info[lv.name]
        end
      end

      it "assigns sizes to each partition to resize" do
        result = creator.populated_devicegraph([pv, vg], ["/dev/sda"])
        devicegraph = result.devicegraph

        root = devicegraph.lvm_lvs.find { |p| p.filesystem_mountpoint == "/" }
        expect(root.size).to eq(1.GiB)

        home = devicegraph.lvm_lvs.find { |p| p.filesystem_mountpoint == "/home" }
        expect(home.size).to eq(3.GiB)
      end
    end
  end
end
