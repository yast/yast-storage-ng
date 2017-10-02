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
  let(:filesystem_type) { Y2Storage::Filesystems::Type::EXT4 }
  let(:mount_by_type) { Y2Storage::Filesystems::MountByType::PATH }
  let(:new_part) do
    Y2Storage::Planned::Partition.new("/home", Y2Storage::Filesystems::Type::EXT4).tap do |part|
      part.fstab_options = ["ro", "acl"]
      part.mkfs_options = "-b 2048"
      part.mount_by = mount_by_type
    end
  end
  let(:scenario) { "windows-linux-free-pc" }
  let(:reusable_part) do
    Y2Storage::Planned::Partition.new("/", filesystem_type).tap do |part|
      part.reuse = "/dev/sda3"
    end
  end

  before { fake_scenario(scenario) }

  subject(:creator) do
    described_class.new(Y2Storage::StorageManager.instance.probed)
  end

  describe "#populated_devicegraph" do
    it "creates new partitions" do
      devicegraph = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      _win, _swap, _root, home = devicegraph.partitions
      expect(home).to have_attributes(
        filesystem_type:       filesystem_type,
        filesystem_mountpoint: "/home"
      )
    end

    it "sets filesystem options" do
      devicegraph = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      home = devicegraph.partitions.last
      fs = home.filesystem
      expect(fs.mkfs_options).to eq("-b 2048")
      expect(fs.fstab_options).to eq(["ro", "acl"])
      expect(fs.mount_by).to eq(mount_by_type)
    end

    it "reuses partitions" do
      devicegraph = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      root = devicegraph.partitions.find { |p| p.filesystem_mountpoint == "/" }
      expect(root).to have_attributes(
        filesystem_label: "root"
      )
    end

    it "ignores other disks" do
      devicegraph = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      sdb = devicegraph.disks.find { |d| d.name == "/dev/sdb" }
      expect(sdb.partitions).to be_empty
    end

    describe "using LVM" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:filesystem_type) { Y2Storage::Filesystems::Type::EXT4 }

      let(:pv) { planned_partition(lvm_volume_group_name: "vg0") }

      let(:lv_root) { planned_lv(mount_point: "/", logical_volume_name: "lv_root") }

      let(:vg) { planned_vg(volume_group_name: "vg0", lvs: [lv_root]) }

      it "adds volume groups" do
        devicegraph = creator.populated_devicegraph([pv, vg], ["/dev/sda"])
        vg = devicegraph.lvm_vgs.first
        expect(vg.lvm_pvs.map(&:blk_device).map(&:name)).to eq(["/dev/sda1"])
        expect(vg.vg_name).to eq("vg0")
        expect(vg.lvm_lvs.map(&:lv_name)).to eq(["lv_root"])
      end

      it "adds logical volumes" do
        devicegraph = creator.populated_devicegraph([pv, vg], ["/dev/sda"])
        lv = devicegraph.lvm_lvs.first
        expect(lv.lv_name).to eq("lv_root")
        expect(lv.lvm_vg.vg_name).to eq("vg0")
      end
    end
  end
end
