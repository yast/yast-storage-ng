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
require "y2storage"

RSpec.shared_examples "boot disk in devicegraph" do
  context "if no there is no filesystem configured as '/' in the devicegraph" do
    let(:scenario) { "double-windows-pc" }

    it "returns a Disk object" do
      expect(analyzer.boot_disk).to be_a Y2Storage::Disk
    end

    it "returns the first disk in the system" do
      expect(analyzer.boot_disk.name).to eq "/dev/sda"
    end
  end

  context "if a partition is configured as '/' in the devicegraph" do
    it "returns a Disk object" do
      expect(analyzer.boot_disk).to be_a Y2Storage::Disk
    end

    it "returns the disk containing the '/' partition" do
      expect(analyzer.boot_disk.name).to eq "/dev/sdb"
    end
  end

  context "if a partition over a Dasd device is configured as '/' in the devicegraph" do
    let(:scenario) { "dasd_50GiB" }

    before do
      partition = Y2Storage::Partition.find_by_name(fake_devicegraph, "/dev/sda1")
      partition.filesystem.mount_point = "/"
    end

    it "returns a Dasd object" do
      expect(analyzer.boot_disk).to be_a Y2Storage::Dasd
    end

    it "returns the dasd device containing the '/' partition" do
      expect(analyzer.boot_disk.name).to eq "/dev/sda"
    end
  end

  context "if a partition over a Multipath device is configured as '/' in the devicegraph" do
    let(:scenario) { "empty-dasd-and-multipath.xml" }

    let(:multipath_name) { "/dev/mapper/36005076305ffc73a00000000000013b4" }

    before do
      device = Y2Storage::BlkDevice.find_by_name(fake_devicegraph, multipath_name)
      part = device.partition_table.create_partition("/dev/#{multipath_name}-1",
        Y2Storage::Region.create(2048, 1048576, 512),
        Y2Storage::PartitionType::PRIMARY)
      fs = part.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
      fs.mount_point = "/"
    end

    it "returns a Multipath object" do
      expect(analyzer.boot_disk).to be_a Y2Storage::Multipath
    end

    it "returns the Multipath device containing the '/' partition" do
      expect(analyzer.boot_disk.name).to eq multipath_name
    end
  end

  context "if a partition over a BIOS RAID is configured as '/' in the devicegraph" do
    let(:scenario) { "empty-dm_raids.xml" }

    let(:raid_name) { "/dev/mapper/isw_ddgdcbibhd_test1" }

    before do
      device = Y2Storage::BlkDevice.find_by_name(fake_devicegraph, raid_name)
      part = device.partition_table.create_partition("/dev/#{raid_name}-1",
        Y2Storage::Region.create(2048, 1048576, 512),
        Y2Storage::PartitionType::PRIMARY)
      fs = part.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
      fs.mount_point = "/"
    end

    it "returns a BIOS RAID" do
      expect(analyzer.boot_disk.is?(:bios_raid)).to eq(true)
    end

    it "returns the BIOS RAID containing the '/' partition" do
      expect(analyzer.boot_disk.name).to eq raid_name
    end
  end

  context "if a LVM LV is configured as '/' in the devicegraph" do
    let(:scenario) { "complex-lvm-encrypt" }

    it "returns a Disk object" do
      expect(analyzer.boot_disk).to be_a Y2Storage::Disk
    end

    it "returns the first disk containing a PV of the involved LVM VG" do
      expect(analyzer.boot_disk.name).to eq "/dev/sdd"
    end
  end
end

describe Y2Storage::BootRequirementsStrategies::Analyzer do
  let(:scenario) { "mixed_disks" }
  let(:devicegraph) { fake_devicegraph }
  let(:boot_name) { "" }
  let(:planned_root) { planned_partition(mount_point: "/") }
  let(:planned_boot) { planned_partition(mount_point: "/boot") }
  let(:planned_devs) { [planned_boot, planned_root] }

  before { fake_scenario(scenario) }

  describe ".new" do
    # There was such a bug, test added to avoid regression"
    it "does not modify the passed collections" do
      initial_graph = devicegraph.dup
      described_class.new(devicegraph, planned_devs, boot_name)

      expect(planned_devs.map(&:mount_point)).to eq ["/boot", "/"]
      expect(devicegraph.actiongraph(from: initial_graph)).to be_empty
    end

    context "when there is a root" do
      let(:scenario) { "mixed_disks" }

      it "stores the root filesystem" do
        analyzer = described_class.new(devicegraph, planned_devs, boot_name)
        expect(analyzer.root_filesystem).to be_a(Y2Storage::Filesystems::Base)
        expect(analyzer.root_filesystem.mount_point).to eq("/")
      end
    end

    context "when there is no root" do
      let(:scenario) { "empty_hard_disk_50GiB" }

      it "does not store a filesystem" do
        analyzer = described_class.new(devicegraph, planned_devs, boot_name)
        expect(analyzer.root_filesystem).to be_nil
      end
    end
  end

  describe "#boot_disk" do
    subject(:analyzer) { described_class.new(devicegraph, planned_devs, boot_name) }

    context "if the name of the boot disk is known and the disk exists" do
      let(:boot_name) { "/dev/sdb" }

      it "returns a Disk object" do
        expect(analyzer.boot_disk).to be_a Y2Storage::Disk
      end

      it "returns the disk matching the given name" do
        expect(analyzer.boot_disk.name).to eq boot_name
      end
    end

    context "if no name is given or there is no such disk" do
      let(:boot_name) { nil }

      context "but '/' is in the list of planned devices" do
        context "and the disk to allocate the planned device is known" do
          context "and the disk exists" do
            before { planned_root.disk = "/dev/sdb" }

            it "returns a Disk object" do
              expect(analyzer.boot_disk).to be_a Y2Storage::Disk
            end

            it "returns the disk where root is planned" do
              expect(analyzer.boot_disk.name).to eq planned_root.disk
            end
          end

          context "but the disk does not exist" do
            before { planned_root.disk = "/dev/sdx" }

            include_examples "boot disk in devicegraph"
          end
        end

        context "and the disk for '/' is not decided" do
          include_examples "boot disk in devicegraph"
        end
      end

      context "and there is no planned device for '/'" do
        include_examples "boot disk in devicegraph"
      end
    end
  end

  describe "#root_in_lvm?" do
    subject(:analyzer) { described_class.new(devicegraph, planned_devs, boot_name) }

    context "if '/' is a planned logical volume" do
      let(:planned_root) { planned_lv(mount_point: "/") }

      it "returns true" do
        expect(analyzer.root_in_lvm?).to eq true
      end
    end

    context "if '/' is a planned partition" do
      let(:planned_root) { planned_partition(mount_point: "/") }

      it "returns false" do
        expect(analyzer.root_in_lvm?).to eq false
      end
    end

    context "if '/' is a logical volume from the devicegraph" do
      let(:planned_devs) { [] }
      let(:scenario) { "complex-lvm-encrypt" }

      it "returns true" do
        expect(analyzer.root_in_lvm?).to eq true
      end
    end

    context "if '/' is a partition from the devicegraph" do
      let(:planned_devs) { [] }
      let(:scenario) { "mixed_disks" }

      it "returns false" do
        expect(analyzer.root_in_lvm?).to eq false
      end
    end

    context "if no device or planned device is configured as '/'" do
      let(:planned_devs) { [] }
      let(:scenario) { "double-windows-pc" }

      it "returns false" do
        expect(analyzer.root_in_lvm?).to eq false
      end
    end
  end

  describe "#root_in_software_raid?" do
    subject(:analyzer) { described_class.new(devicegraph, planned_devs, boot_name) }

    context "if '/' is a planned software raid" do
      let(:planned_root) { planned_md(mount_point: "/") }

      it "returns true" do
        expect(analyzer.root_in_software_raid?).to eq true
      end
    end

    context "if '/' is a planned partition" do
      let(:planned_root) { planned_partition(mount_point: "/") }

      it "returns false" do
        expect(analyzer.root_in_software_raid?).to eq false
      end
    end

    context "if '/' is a planned logical volume" do
      let(:planned_root) { planned_lv(mount_point: "/") }

      it "returns false" do
        expect(analyzer.root_in_software_raid?).to eq false
      end
    end

    context "if '/' is a software raid from the devicegraph" do
      let(:planned_devs) { [] }
      let(:scenario) { "md2-devicegraph.xml" }

      before do
        md = Y2Storage::Md.find_by_name(fake_devicegraph, "/dev/md0")
        md.remove_descendants
        fs = md.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
        fs.mount_point = "/"
      end

      it "returns true" do
        expect(analyzer.root_in_software_raid?).to eq true
      end
    end

    context "if '/' is a partition over a software raid from the devicegraph" do
      let(:planned_devs) { [] }
      let(:scenario) { "md2-devicegraph.xml" }

      before do
        md = Y2Storage::Md.find_by_name(fake_devicegraph, "/dev/md0")
        part = md.partition_table.create_partition("/dev/md0-1",
          Y2Storage::Region.create(2048, 1048576, 512),
          Y2Storage::PartitionType::PRIMARY)
        fs = part.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
        fs.mount_point = "/"
      end

      it "returns true" do
        expect(analyzer.root_in_software_raid?).to eq true
      end
    end

    context "if '/' is a partition over a disk from the devicegraph" do
      let(:planned_devs) { [] }
      let(:scenario) { "mixed_disks" }

      it "returns false" do
        expect(analyzer.root_in_software_raid?).to eq false
      end
    end

    context "if '/' is a logical volume from the devicegraph" do
      let(:planned_devs) { [] }
      let(:scenario) { "complex-lvm-encrypt" }

      it "returns false" do
        expect(analyzer.root_in_software_raid?).to eq false
      end
    end

    context "if no device or planned device is configured as '/'" do
      let(:planned_devs) { [] }
      let(:scenario) { "double-windows-pc" }

      it "returns false" do
        expect(analyzer.root_in_software_raid?).to eq false
      end
    end
  end

  describe "#encrypted_root?" do
    subject(:analyzer) { described_class.new(devicegraph, planned_devs, boot_name) }

    context "if '/' is a planned plain logical volume" do
      let(:planned_root) { planned_lv(mount_point: "/") }

      it "returns false" do
        expect(analyzer.encrypted_root?).to eq false
      end
    end

    context "if '/' is a planned encrypted logical volume" do
      let(:planned_root) { planned_lv(mount_point: "/", encryption_password: "12345678") }

      it "returns true" do
        expect(analyzer.encrypted_root?).to eq true
      end
    end

    context "if '/' is a planned plain partition" do
      let(:planned_root) { planned_partition(mount_point: "/") }

      it "returns false" do
        expect(analyzer.encrypted_root?).to eq false
      end
    end

    context "if '/' is a planned encrypted partition" do
      let(:planned_root) { planned_partition(mount_point: "/", encryption_password: "12345678") }

      it "returns true" do
        expect(analyzer.encrypted_root?).to eq true
      end
    end

    context "if '/' is a plain partition from the devicegraph" do
      let(:planned_devs) { [] }
      let(:scenario) { "mixed_disks" }

      it "returns false" do
        expect(analyzer.encrypted_root?).to eq false
      end
    end

    context "if '/' is an encrypted partition from the devicegraph" do
      let(:planned_devs) { [] }
      let(:scenario) { "output/empty_hard_disk_gpt_50GiB-enc" }

      it "returns true" do
        expect(analyzer.encrypted_root?).to eq true
      end
    end

    context "if no device or planned device is configured as '/'" do
      let(:planned_devs) { [] }
      let(:scenario) { "double-windows-pc" }

      it "returns false" do
        expect(analyzer.encrypted_root?).to eq false
      end
    end
  end

  describe "#btrfs_root?" do
    subject(:analyzer) { described_class.new(devicegraph, planned_devs, boot_name) }
    let(:ext4) { Y2Storage::Filesystems::Type::EXT4 }
    let(:btrfs) { Y2Storage::Filesystems::Type::BTRFS }

    context "if '/' is a non-btrfs planned logical volume" do
      let(:planned_root) { planned_lv(mount_point: "/", type: ext4) }

      it "returns false" do
        expect(analyzer.btrfs_root?).to eq false
      end
    end

    context "if '/' is a btrfs planned logical volume" do
      let(:planned_root) { planned_lv(mount_point: "/", type: btrfs) }

      it "returns true" do
        expect(analyzer.btrfs_root?).to eq true
      end
    end

    context "if '/' is a non-btrfs plain partition" do
      let(:planned_root) { planned_partition(mount_point: "/", type: ext4) }

      it "returns false" do
        expect(analyzer.btrfs_root?).to eq false
      end
    end

    context "if '/' is a planned encrypted partition" do
      let(:planned_root) { planned_partition(mount_point: "/", type: btrfs) }

      it "returns true" do
        expect(analyzer.btrfs_root?).to eq true
      end
    end

    context "if '/' is a non-btrfs device from the devicegraph" do
      let(:planned_devs) { [] }
      let(:scenario) { "complex-lvm-encrypt" }

      it "returns false" do
        expect(analyzer.btrfs_root?).to eq false
      end
    end

    context "if '/' is an encrypted device from the devicegraph" do
      let(:planned_devs) { [] }
      let(:scenario) { "mixed_disks" }

      it "returns true" do
        expect(analyzer.btrfs_root?).to eq true
      end
    end

    context "if no device or planned device is configured as '/'" do
      let(:planned_devs) { [] }
      let(:scenario) { "double-windows-pc" }

      it "returns false" do
        expect(analyzer.btrfs_root?).to eq false
      end
    end
  end

  describe "#boot_ptable_type?" do
    subject(:analyzer) { described_class.new(devicegraph, planned_devs, boot_name) }
    let(:scenario) { "gpt_msdos_and_empty" }

    before do
      allow(analyzer).to receive(:boot_disk) do
        Y2Storage::Disk.find_by_name(fake_devicegraph, disk_name)
      end
    end

    context "if there are no disks" do
      before { allow(analyzer).to receive(:boot_disk).and_return nil }

      it "returns false all the partition types" do
        expect(analyzer.boot_ptable_type?(:gpt)).to eq false
        expect(analyzer.boot_ptable_type?(:msdos)).to eq false
        expect(analyzer.boot_ptable_type?(:dasd)).to eq false
      end
    end

    context "if the boot disk contains no partition table" do
      let(:disk_name) { "/dev/sde" }

      it "returns true for GPT (the default proposal type)" do
        expect(analyzer.boot_ptable_type?(:gpt)).to eq true
      end

      it "returns false for any other type" do
        expect(analyzer.boot_ptable_type?(:msdos)).to eq false
        expect(analyzer.boot_ptable_type?(:dasd)).to eq false
      end
    end

    context "if the boot disk contains a GPT partition table" do
      let(:disk_name) { "/dev/sdc" }

      it "returns true for GPT" do
        expect(analyzer.boot_ptable_type?(:gpt)).to eq true
      end

      it "returns false for any other type" do
        expect(analyzer.boot_ptable_type?(:msdos)).to eq false
        expect(analyzer.boot_ptable_type?(:dasd)).to eq false
      end
    end

    context "if the boot disk contains a MSDOS partition table" do
      let(:disk_name) { "/dev/sda" }

      it "returns true for MSDOS" do
        expect(analyzer.boot_ptable_type?(:msdos)).to eq true
      end

      it "returns false for any other type" do
        expect(analyzer.boot_ptable_type?(:gpt)).to eq false
        expect(analyzer.boot_ptable_type?(:dasd)).to eq false
      end
    end
  end

  describe "#free_mountpoint?" do
    subject(:analyzer) { described_class.new(devicegraph, planned_devs, boot_name) }
    let(:point) { "/home" }

    context "if there is a planned device for the queried mount point" do
      let(:planned_devs) { [planned_partition(mount_point: "/some-dir")] }
      let(:point) { "/some-dir" }

      it "returns false" do
        expect(analyzer.free_mountpoint?(point)).to eq false
      end
    end

    context "if there is no planned device for the mount point" do
      context "but the queried mount point is already assigned in the devicegraph" do
        let(:scenario) { "mixed_disks" }
        let(:planned_devs) { [planned_partition(mount_point: "/home")] }

        it "returns false" do
          expect(analyzer.free_mountpoint?(point)).to eq false
        end
      end

      context "and the mount point is not used in the devicegraph either" do
        let(:scenario) { "double-windows-pc" }

        it "returns true" do
          expect(analyzer.free_mountpoint?(point)).to eq true
        end
      end
    end
  end

  describe "#planned_prep_partitions" do
    subject(:analyzer) { described_class.new(devicegraph, planned_devs, boot_name) }
    let(:planned_prep) { planned_partition(partition_id: Y2Storage::PartitionId::PREP) }
    let(:planned_devs) do
      [planned_lv, planned_prep, planned_partition(partition_id: Y2Storage::PartitionId::LVM)]
    end

    it "returns a list of the planned partitions with the PReP id" do
      expect(analyzer.planned_prep_partitions).to eq [planned_prep]
    end
  end

  describe "#planned_grub_partitions" do
    subject(:analyzer) { described_class.new(devicegraph, planned_devs, boot_name) }
    let(:planned_grub) { planned_partition(partition_id: Y2Storage::PartitionId::BIOS_BOOT) }
    let(:planned_devs) do
      [planned_lv, planned_partition(partition_id: Y2Storage::PartitionId::PREP), planned_grub]
    end

    it "returns a list of the planned partitions with the BIOS boot id" do
      expect(analyzer.planned_grub_partitions).to eq [planned_grub]
    end
  end
end
