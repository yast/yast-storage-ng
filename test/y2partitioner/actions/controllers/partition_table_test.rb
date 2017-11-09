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

describe Y2Partitioner::Actions::Controllers::PartitionTable do
  context "PC with 2 disks" do
    before do
      devicegraph_stub("mixed_disks_btrfs.yml")
    end

    subject { described_class.new(disk_name) }
    let(:disk_name) { "/dev/sdb" }

    describe "#new" do
      it "has an initial type" do
        expect(subject.type).to eq Y2Storage::PartitionTables::Type::MSDOS
      end
    end

    describe "#disk" do
      it "returns a Y2Storage::Disk" do
        expect(subject.disk).to be_a(Y2Storage::Disk)
      end

      it "returns the correct disk" do
        expect(subject.disk.name).to eq(disk_name)
      end
    end

    describe "#wizard_title" do
      it "has the correct disk name in the wizard title" do
        expect(subject.wizard_title).to include disk_name
      end
    end

    describe "#possible_partition_table_types" do
      it "returns MS-DOS and GPT for a normal PC-style disk" do
        types = subject.possible_partition_table_types
        expect(types.size).to be == 2
        expect(types).to include Y2Storage::PartitionTables::Type::MSDOS
        expect(types).to include Y2Storage::PartitionTables::Type::GPT
      end
    end

    describe "#can_create_partition_table?" do
      it "detects that it can create a partition table" do
        expect(subject.can_create_partition_table?).to eq true
      end
    end

    describe "#multiple_types?" do
      it "detects that there are multiple partition table types to choose from" do
        expect(subject.multiple_types?).to eq true
      end
    end

    describe "#create_partition_table" do
      it "has partitions and an MS-DOS partition table before" do
        expect(subject.disk.partitions.size).to be > 0
        expect(subject.disk.partition_table.type).to eq Y2Storage::PartitionTables::Type::MSDOS
      end

      it "afterwards has no more partitions, but a GPT partition table" do
        subject.type = Y2Storage::PartitionTables::Type::GPT
        subject.create_partition_table
        expect(subject.disk.partitions.empty?).to be true
        expect(subject.disk.partition_table.type).to eq Y2Storage::PartitionTables::Type::GPT
      end
    end
  end

  context "S/390 DASD" do
    before do
      devicegraph_stub("dasd_50GiB.yml")
    end

    subject { described_class.new(disk_name) }
    let(:disk_name) { "/dev/sda" }

    describe "#new" do
      it "has an initial type" do
        expect(subject.type).to eq Y2Storage::PartitionTables::Type::DASD
      end
    end

    describe "#disk" do
      it "returns a Y2Storage::Dasd" do
        expect(subject.disk).to be_a(Y2Storage::Dasd)
      end

      it "returns the correct disk" do
        expect(subject.disk.name).to eq(disk_name)
      end
    end

    describe "#possible_partition_table_types" do
      it "returns only type DASD" do
        expect(subject.possible_partition_table_types).to eq [Y2Storage::PartitionTables::Type::DASD]
      end
    end

    describe "#can_create_partition_table?" do
      it "detects that it can create a partition table" do
        expect(subject.can_create_partition_table?).to eq true
      end
    end

    describe "#multiple_types?" do
      it "detects that there is only one possible partition table type" do
        expect(subject.multiple_types?).to eq false
      end
    end

    describe "#create_partition_table" do
      it "has a partition and a DASD partition table before" do
        expect(subject.disk.partitions.size).to be > 0
        expect(subject.disk.partition_table.type).to eq Y2Storage::PartitionTables::Type::DASD
      end

      it "afterwards has no more partitions, but still a DASD partition table" do
        subject.create_partition_table
        expect(subject.disk.partitions.empty?).to be true
        expect(subject.disk.partition_table.type).to eq Y2Storage::PartitionTables::Type::DASD
      end
    end
  end
end
