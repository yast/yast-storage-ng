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
require "y2partitioner/sequences/controllers/partition"

describe Y2Partitioner::Sequences::Controllers::Partition do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  subject { described_class.new(disk_name) }

  describe "#disk" do
    let(:disk_name) { "/dev/sda" }

    it "returns a Y2Storage::Disk" do
      expect(subject.disk).to be_a(Y2Storage::Disk)
    end

    it "returns the currently editing disk" do
      expect(subject.disk.name).to eq(disk_name)
    end
  end

  describe "#unused_slots" do
    let(:disk_name) { "/dev/sdb" }

    it "returns a list of PartitionSlot" do
      slots = subject.unused_slots
      expect(slots).to be_a(Array)
      expect(slots).to all(be_a(Y2Storage::PartitionTables::PartitionSlot))
    end

    it "returns the unused slots for the currently editing disk" do
      expect(subject.unused_slots.inspect)
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

  describe "#new_partition_possible?" do
    let(:disk_name) { "/dev/sda" }

    before do
      allow(subject).to receive(:unused_slots).and_return(slots)
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
