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

require_relative "../../test_helper"
require "y2partitioner/actions/controllers/partition"

describe Y2Partitioner::Actions::Controllers::Partition do
  before do
    devicegraph_stub(scenario)
  end

  subject(:controller) { described_class.new(disk_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks_btrfs.yml" }

  describe "#disk" do
    let(:disk_name) { "/dev/sda" }

    it "returns a Y2Storage::Disk" do
      expect(subject.disk).to be_a(Y2Storage::Disk)
    end

    it "returns the currently editing disk" do
      expect(subject.disk.name).to eq(disk_name)
    end
  end

  describe "#unused_optimal_slots" do
    let(:disk_name) { "/dev/sdb" }

    it "returns a list of PartitionSlot" do
      slots = subject.unused_optimal_slots
      expect(slots).to be_a(Array)
      expect(slots).to all(be_a(Y2Storage::PartitionTables::PartitionSlot))
    end

    it "returns the unused optimally aligned slots for the currently editing disk" do
      expect(subject.unused_optimal_slots.inspect)
        .to eq(subject.disk.partition_table.unused_partition_slots.inspect)
    end
  end

  describe "#create_partition" do
    let(:disk_name) { "/dev/sdc" }

    before do
      allow(subject).to receive(:region).and_return(subject.unused_slots.first.region)
      allow(subject).to receive(:type).and_return(Y2Storage::PartitionType::PRIMARY)
    end

    it "creates a new partition in the currently editing disk" do
      expect(subject.disk.partitions).to be_empty
      subject.create_partition
      expect(subject.disk.partitions).to_not be_empty
    end

    it "stores the new created partition" do
      expect(subject.partition).to be_nil
      subject.create_partition
      expect(subject.partition).to eq(subject.disk.partitions.first)
    end

    describe "alignment" do
      let(:scenario) { "dasd1.xml" }
      let(:disk_name) { "/dev/dasda" }

      before do
        allow(subject).to receive(:region).and_return(subject.unused_slots.first.region)
      end

      # TODO: Test new arguments
      # End if disk in DASD? end of disk in GPT?
    end
  end

  describe "#delete_partition" do
    let(:disk_name) { "/dev/sda" }

    before do
      allow(subject).to receive(:region).and_return(subject.unused_slots.first.region)
      allow(subject).to receive(:type).and_return(Y2Storage::PartitionType::PRIMARY)
      subject.create_partition
    end

    it "deletes the new partition created in the currently editing disk" do
      partitions = subject.disk.partitions.map(&:name)
      new_partition = subject.partition.name

      expect(partitions).to include(new_partition)

      subject.delete_partition

      expect(subject.disk.partitions.size).to eq(partitions.size - 1)
      expect(subject.disk.partitions.map(&:name)).to_not include(new_partition)
    end

    it "clears the new created partition" do
      expect(subject.partition).to_not be_nil
      subject.delete_partition
      expect(subject.partition).to be_nil
    end
  end

  describe "#delete_filesystem" do
    let(:disk_name) { "/dev/sda" }

    before do
      allow(subject).to receive(:disk).and_return(disk)
    end

    let(:disk) { instance_double(Y2Storage::Disk) }

    it "deletes the filesystem over the disk" do
      expect(controller.disk).to receive(:delete_filesystem)
      controller.delete_filesystem
    end
  end

  describe "#disk_used?" do
    let(:scenario) { "empty_hard_disk_50GiB.yml" }

    let(:disk_name) { "/dev/sda" }

    context "when the disk is not in use" do
      it "returns false" do
        expect(subject.disk_used?).to eq(false)
      end
    end

    context "when the disk is in use" do
      before do
        vg = Y2Storage::LvmVg.create(current_graph, "vg0")
        vg.add_lvm_pv(subject.disk)
      end

      it "returns true" do
        expect(subject.disk_used?).to eq(true)
      end
    end
  end

  describe "#disk_used?" do
    context "when the disk is used as physical volume" do
      let(:scenario) { "empty_hard_disk_50GiB" }

      let(:disk_name) { "/dev/sda" }

      before do
        vg = Y2Storage::LvmVg.create(current_graph, "vg0")
        vg.add_lvm_pv(subject.disk)
      end

      it "returns true" do
        expect(subject.disk_used?).to eq(true)
      end
    end

    context "when the disk belongs to a MD RAID" do
      let(:scenario) { "empty_hard_disk_50GiB" }

      let(:disk_name) { "/dev/sda" }

      before do
        md = Y2Storage::Md.create(current_graph, "/dev/md0")
        md.add_device(subject.disk)
      end

      it "returns true" do
        expect(subject.disk_used?).to eq(true)
      end
    end

    context "when the disk has a partition table" do
      let(:scenario) { "md_raid.xml" }

      let(:disk_name) { "/dev/sda" }

      it "returns false" do
        expect(subject.disk_used?).to eq(false)
      end
    end

    context "when the disk is formatted" do
      let(:scenario) { "empty_hard_disk_50GiB" }

      let(:disk_name) { "/dev/sda" }

      before do
        subject.disk.create_filesystem(Y2Storage::Filesystems::Type::EXT3)
      end

      it "returns false" do
        expect(subject.disk_used?).to eq(false)
      end
    end

    context "when the disk is empty" do
      let(:scenario) { "empty_hard_disk_50GiB" }

      let(:disk_name) { "/dev/sda" }

      it "returns false" do
        expect(subject.disk_used?).to eq(false)
      end
    end
  end

  describe "#disk_formatted?" do
    let(:disk_name) { "/dev/sda" }

    before do
      allow(subject).to receive(:disk).and_return(disk)
    end

    let(:disk) { instance_double(Y2Storage::Disk, formatted?: formatted) }

    context "when the disk is not formatted" do
      let(:formatted) { false }

      it "returns false" do
        expect(subject.disk_formatted?).to eq(false)
      end
    end

    context "when the disk is formatted" do
      let(:formatted) { true }

      it "returns true" do
        expect(subject.disk_formatted?).to eq(true)
      end
    end
  end

  describe "#new_partition_possible?" do
    let(:disk_name) { "/dev/sda" }

    before do
      allow(subject).to receive(:unused_optimal_slots).and_return(slots)
    end

    context "when there is not free space in the currently editing disk" do
      let(:slots) { [] }

      it "returns false" do
        expect(subject.new_partition_possible?).to eq(false)
      end
    end

    context "when there are not available slots in the currently editing disk" do
      let(:slots) { [double("slot", available?: false)] }

      it "returns false" do
        expect(subject.new_partition_possible?).to eq(false)
      end
    end

    context "when there are available slots in the currently editing disk" do
      let(:slots) { [double("slot", available?: true)] }

      it "returns true" do
        expect(subject.new_partition_possible?).to eq(true)
      end
    end
  end
end
