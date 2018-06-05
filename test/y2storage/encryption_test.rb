#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

describe Y2Storage::Encryption do
  describe ".dm_name_for" do
    # Helper method to find a partition by number
    def partition(disk, number)
      disk.partitions.find { |part| part.number == number }
    end

    # Helper method to check for collisions in the DeviceMapper names
    def expect_no_dm_duplicates
      all_dm_names = devicegraph.blk_devices.map(&:dm_table_name).reject(&:empty?).sort
      uniq_dm_names = all_dm_names.uniq
      expect(all_dm_names).to eq uniq_dm_names
    end

    before { fake_scenario("trivial_lvm_and_other_partitions") }

    let(:devicegraph) { Y2Storage::StorageManager.instance.staging }
    let(:sda) { devicegraph.find_by_name("/dev/sda") }

    context "when the numbers assigned to partitions change" do
      # Helper method to delete a given partition from a disk
      def delete_partition(disk, number)
        disk.partition_table.delete_partition(partition(disk, number))
      end

      # Helper method to create a partition with an encryption device,
      # using Encryption.dm_name_for to calculate the name of the latter.
      def create_encrypted_partition(disk, slot_index)
        slot = disk.partition_table.unused_partition_slots[slot_index]
        region = Y2Storage::Region.create(slot.region.start, 8192, slot.region.block_size)
        part = disk.partition_table.create_partition(
          slot.name, region, Y2Storage::PartitionType::PRIMARY
        )
        enc_name = Y2Storage::Encryption.dm_name_for(part)
        part.create_encryption(enc_name)
      end

      before do
        # Let's free some slots at the beginning of the disk
        delete_partition(sda, 1)
        delete_partition(sda, 2)
      end

      # Regression test for bsc#1094157
      it "does not generate redundant DeviceMapper names" do
        # Generate encryption devices for two new partitions sda1 and sda2
        # at the beginning of the disk
        create_encrypted_partition(sda, 0)
        create_encrypted_partition(sda, 0)
        # Remove the first new partition so the current sda2 becomes sda1
        delete_partition(sda, 1)
        # Add a new sda2
        create_encrypted_partition(sda, 1)

        expect_no_dm_duplicates
      end
    end

    context "when the candidate name is already taken" do
      let(:sda2) { partition(sda, 2) }
      let(:sda3) { partition(sda, 3) }

      before do
        # Ensure the first option for the name is already taken
        enc_name = Y2Storage::Encryption.dm_name_for(sda2)
        sda3.encryption.dm_table_name = enc_name
      end

      it "does not generate redundant DeviceMapper names" do
        sda2.create_encryption(Y2Storage::Encryption.dm_name_for(sda2))
        expect_no_dm_duplicates
      end
    end
  end
end
