#!/usr/bin/env rspec
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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::Disk do
  using Y2Storage::Refinements::SizeCasts

  before do
    fake_scenario(scenario)
  end
  let(:scenario) { "gpt_msdos_and_empty" }
  let(:disk_name) { "/dev/sda" }
  subject(:disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, disk_name) }

  describe "#preferred_ptable_type" do
    it "returns gpt" do
      expect(subject.preferred_ptable_type).to eq Y2Storage::PartitionTables::Type::GPT
    end
  end

  describe "#free_spaces" do

    context "in a disk with no partition table, no PV and no filesystem" do
      let(:disk_name) { "/dev/sde" }

      it "returns an array with just one element" do
        expect(disk.free_spaces.size).to eq 1
      end

      it "considers the whole disk to be free space" do
        space = disk.free_spaces.first
        expect(space.region.start).to eq 0
        expect(space.disk_size).to eq disk.size
      end
    end

    context "in a directly formated disk (filesystem but no partition table)" do
      let(:disk_name) { "/dev/sdf" }

      it "returns an empty array" do
        expect(disk.free_spaces).to be_empty
      end
    end

    context "in a disk directly used as LVM PV (no partition table)" do
      let(:disk_name) { "/dev/sdg" }

      it "returns an empty array" do
        expect(disk.free_spaces).to be_empty
      end
    end

    context "in a disk with an empty GPT partition table" do
      let(:disk_name) { "/dev/sdd" }

      let(:ptable_size) { 1.MiB }
      # The final 16.5 KiB are reserved by GPT
      let(:gpt_final_space) { 16.5.KiB }

      it "returns an array with just one element" do
        expect(disk.free_spaces.size).to eq 1
      end

      it "starts counting right after the partition table" do
        region = disk.free_spaces.first.region
        expect(region.start).to eq(ptable_size.to_i / region.block_size.to_i)
      end

      it "discards the space reserved by GPT at the end of the disk" do
        region = disk.free_spaces.first.region
        discarded = disk.region.end - region.end
        expect(region.block_size * discarded).to eq gpt_final_space
      end
    end

    context "in a disk with an empty MBR partition table" do
      let(:disk_name) { "/dev/sdb" }
      let(:ptable_size) { 1.MiB }

      it "returns an array with just one element" do
        expect(disk.free_spaces.size).to eq 1
      end

      it "starts counting right after the partition table" do
        region = disk.free_spaces.first.region
        expect(region.start).to eq(ptable_size.to_i / region.block_size.to_i)
      end

      it "counts after the end of the disk" do
        region = disk.free_spaces.first.region
        expect(region.end).to eq disk.region.end
      end
    end

    context "in a disk with a fully used partition table" do
      let(:disk_name) { "/dev/sda" }

      it "returns an empty array" do
        expect(disk.free_spaces).to be_empty
      end
    end

    context "in a disk with some partitions and some free slots" do
      let(:disk_name) { "/dev/sdc" }

      let(:ptable_size) { 1.MiB }
      let(:gpt_final_space) { 16.5.KiB }

      it "returns one element for each slot" do
        expect(disk.free_spaces.size).to eq 2
      end

      it "calculates properly the size of each free slot" do
        sorted = disk.free_spaces.sort_by { |s| s.region.start }

        expect(sorted.first.disk_size).to eq 500.GiB
        last_size = 1.TiB - 500.GiB - 60.GiB - ptable_size - gpt_final_space
        expect(sorted.last.disk_size).to eq(last_size)
      end
    end
  end

  describe "#gpt?" do
    context "for a disk with a MBR partition table" do
      let(:disk_name) { "/dev/sda" }

      it "returns false" do
        expect(disk.gpt?).to eq false
      end
    end

    context "for a disk with a GPT partition table" do
      let(:disk_name) { "/dev/sdc" }

      it "returns true" do
        expect(disk.gpt?).to eq true
      end
    end

    context "for a completely empty disk" do
      let(:disk_name) { "/dev/sde" }

      it "returns false" do
        expect(disk.gpt?).to eq false
      end
    end

    context "for a directly formatted disk (filesystem but not partition table)" do
      let(:disk_name) { "/dev/sdf" }

      it "returns false" do
        expect(disk.gpt?).to eq false
      end
    end
  end

  describe "#partition_table" do
    context "for a disk with a partition table" do
      let(:disk_name) { "/dev/sda" }

      it "returns the corresponding PartitionTable object" do
        expect(disk.partition_table).to be_a Y2Storage::PartitionTables::Base
        expect(disk.partition_table.partitionable).to eq disk
      end
    end

    context "for a completely empty disk" do
      let(:disk_name) { "/dev/sde" }

      it "returns nil" do
        expect(disk.partition_table).to be_nil
      end
    end

    context "for a directly formatted disk (filesystem but not partition table)" do
      let(:disk_name) { "/dev/sdf" }

      it "returns nil" do
        expect(disk.partition_table).to be_nil
      end
    end
  end

  describe "#name_or_partition?" do
    let(:scenario) { "mixed_disks" }
    let(:disk_name) { "/dev/sdb" }

    it "returns true for the disk device name" do
      expect(disk.name_or_partition?("/dev/sdb")).to eq true
    end

    it "returns true for the device name of one of the primary partitions" do
      expect(disk.name_or_partition?("/dev/sdb1")).to eq true
    end

    it "returns true for the device name of the extended partition" do
      expect(disk.name_or_partition?("/dev/sdb4")).to eq true
    end

    it "returns true for the device name of one of the logical partitions" do
      expect(disk.name_or_partition?("/dev/sdb6")).to eq true
    end

    it "returns false for any other device name" do
      expect(disk.name_or_partition?("/dev/sda")).to eq false
    end

    it "returns false for an invalid device name" do
      expect(disk.name_or_partition?("wrong name")).to eq false
    end
  end

  describe ".find_by_name_or_partition" do
    let(:scenario) { "mixed_disks" }

    it "returns the disk object with the searched device name" do
      disk = described_class.find_by_name_or_partition(fake_devicegraph, "/dev/sdb")
      expect(disk).to be_a Y2Storage::Disk
      expect(disk.name).to eq "/dev/sdb"
    end

    it "returns the disk object containing a partition with the searched device name" do
      disk = described_class.find_by_name_or_partition(fake_devicegraph, "/dev/sdb1")
      expect(disk).to be_a Y2Storage::Disk
      expect(disk.name).to eq "/dev/sdb"
      expect(disk.partitions.map(&:name)).to include "/dev/sdb1"
    end

    it "returns nil if there are no disks or partitions with the searched device name" do
      expect(described_class.find_by_name_or_partition(fake_devicegraph, "/dev/sda10")).to be_nil
    end

    it "returns nil when searching for an invalid device name" do
      expect(described_class.find_by_name_or_partition(fake_devicegraph, "where art thou?")).to be_nil
    end
  end

  describe "#is?" do
    let(:disk_name) { "/dev/sda" }

    it "returns true for values whose symbol is :disk" do
      expect(disk.is?(:disk)).to eq true
      expect(disk.is?("disk")).to eq true
    end

    it "returns false for a different string like \"Disk\"" do
      expect(disk.is?("Disk")).to eq false
    end

    it "returns false for different device names like :partition or :filesystem" do
      expect(disk.is?(:partition)).to eq false
      expect(disk.is?(:filesystem)).to eq false
    end

    it "returns true for a list of names containing :disk" do
      expect(disk.is?(:disk, :partition)).to eq true
    end

    it "returns false for a list of names not containing :disk" do
      expect(disk.is?(:filesystem, :partition)).to eq false
    end
  end

  describe "#usb?" do
    let(:disk_name) { "/dev/sda" }

    # Minimum test (we cannot simulate USB disks right now) to ensure it does
    # not crash (as it used to do at a point in time)
    it "returns a boolean value" do
      expect(disk.usb?).to eq false
    end
  end

  describe "#mbr_gap" do
    let(:scenario) { "gpt_and_msdos" }

    def disk(disk_name)
      Y2Storage::Disk.find_by_name(fake_devicegraph, disk_name)
    end

    it "returns nil for a disk without partition table" do
      expect(disk("/dev/sde").mbr_gap).to be_nil
    end

    it "returns nil for a GPT disk without partitions" do
      expect(disk("/dev/sdd").mbr_gap).to be_nil
    end

    it "returns nil for a GPT disk with partitions" do
      expect(disk("/dev/sdb").mbr_gap).to be_nil
    end

    it "returns nil for a MS-DOS disk without partitions" do
      expect(disk("/dev/sdc").mbr_gap).to be_nil
    end

    it "returns the gap for a MS-DOS disk with partitions" do
      expect(disk("/dev/sda").mbr_gap).to eq 1.MiB
      expect(disk("/dev/sdf").mbr_gap).to eq 0.MiB
    end
  end

  describe "#swap_partitions" do
    let(:scenario) { "mixed_disks" }

    context "for a disk with no swap partitions" do
      let(:disk_name) { "/dev/sda" }

      it "returns an empty array" do
        expect(disk.swap_partitions).to be_empty
      end
    end

    context "for a disk with swap partitions" do
      let(:disk_name) { "/dev/sdb" }

      it "returns an array of partitions" do
        expect(disk.swap_partitions).to be_a Array
        expect(disk.swap_partitions.size).to eq 1
        expect(disk.swap_partitions.first).to be_a Y2Storage::Partition
      end
    end
  end

  describe ".all" do
    let(:scenario) { "autoyast_drive_examples" }

    it "returns a list of Y2Storage::Disk objects" do
      disks = Y2Storage::Disk.all(fake_devicegraph)
      expect(disks).to be_an Array
      expect(disks).to all(be_a(Y2Storage::Disk))
    end

    it "includes all disks in the devicegraph and nothing else" do
      disks = Y2Storage::Disk.all(fake_devicegraph)
      expect(disks.map(&:basename)).to contain_exactly(
        "sda", "sdb", "sdc", "sdd", "sdaa", "sdf", "nvme0n1", "sdh"
      )
    end
  end

  describe ".sorted_by_name" do
    let(:scenario) { "sorting/disks_and_dasds1" }

    it "returns a list of Y2Storage::Disk objects" do
      disks = Y2Storage::Disk.sorted_by_name(fake_devicegraph)
      expect(disks).to be_an Array
      expect(disks).to all(be_a(Y2Storage::Disk))
    end

    it "includes all disks in the devicegraph, sorted by name, and nothing else" do
      disks = Y2Storage::Disk.sorted_by_name(fake_devicegraph)
      expect(disks.map(&:basename)).to eq [
        "nvme0n1", "nvme0n2", "nvme1n1", "sda", "sdb", "sdc", "sdaa"
      ]
    end

    context "even if Disk.all returns an unsorted array" do
      before do
        allow(Y2Storage::Disk).to receive(:all) do |devicegraph|
          # Let's shuffle things a bit
          shuffle(Y2Storage::Partitionable.all(devicegraph).select { |i| i.is?(:disk) })
        end
      end

      it "returns an array sorted by name" do
        disks = Y2Storage::Disk.sorted_by_name(fake_devicegraph)
        expect(disks.map(&:basename)).to eq [
          "nvme0n1", "nvme0n2", "nvme1n1", "sda", "sdb", "sdc", "sdaa"
        ]
      end
    end
  end
end
