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

describe Y2Storage::PartitionTables::Base do
  using Y2Storage::Refinements::SizeCasts

  before { fake_scenario(scenario) }

  let(:scenario) { "mixed_disks" }

  # Testing this because it's a nice example of usage of the Ruby wrapper
  # and because it was broken at some point
  describe "#inspect" do
    subject(:ptable) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sdb").partition_table }

    it "includes the partition table type" do
      expect(ptable.inspect).to include "Msdos"
    end

    it "includes all the partitions" do
      expect(ptable.inspect).to include "Partition /dev/sdb1 4 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb2 60 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb3 60 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb4 810 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb5 300 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb6 500 GiB"
      expect(ptable.inspect).to include "Partition /dev/sdb7 10237 MiB"
    end
  end

  describe "#delete_all_partitions" do
    subject(:ptable) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sdb").partition_table }

    it "deletes all partitions in table" do
      # NOTE: it is important here to have partition table with logical partitions
      # as it need special handling, so test will cover it
      ptable.delete_all_partitions
      expect(ptable.partitions).to be_empty
    end
  end

  # This test ensures the behavior of libstorage is stable in the future, because, in order
  # to generate aligned partitions, the proposal code heavily relies on the fact that
  # Y2Storage::PartitionTable#unused_partition_slots returns start aligned regions.
  describe "#unused_partition_slots" do
    let(:scenario) { "alignment" }

    let(:sda) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }
    let(:sdb) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sdb") }
    let(:sdc) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sdc") }

    let(:sda_slot) { sda.partition_table.unused_partition_slots.first }
    let(:sdb_slot) { sdb.partition_table.unused_partition_slots.first }
    let(:sdc_slot) { sdc.partition_table.unused_partition_slots.first }

    it "always returns start aligned slots" do
      expect(sda_slot.region.start).to eq(4096)
      expect(sdb_slot.region.start).to eq(4096)
      expect(sdc_slot.region.start).to eq(4096)
    end

    it "returns all space till end" do
      gpt_reserved_blocks = 16.5.KiB.to_i / sda.region.block_size.to_i

      expect(sda_slot.region.end).to eq(sda.region.end - gpt_reserved_blocks)
      expect(sdc_slot.region.end).to eq(sdc.region.end)
    end
  end
end
