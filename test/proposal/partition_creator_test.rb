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
require "storage"
require "y2storage"

describe Y2Storage::Proposal::PartitionCreator do
  describe "#create_partitions" do
    using Y2Storage::Refinements::SizeCasts
    using Y2Storage::Refinements::DevicegraphLists

    before do
      fake_scenario(scenario)
    end

    let(:root_part) { proposed_partition(mount_point: "/", type: :ext4, disk_size: 1.GiB) }
    let(:home_part) { proposed_partition(mount_point: "/home", type: :ext4, disk_size: 1.GiB) }
    let(:swap_part) { proposed_partition(mount_point: "swap", type: :swap, disk_size: 1.GiB) }
    let(:disk_spaces) { fake_devicegraph.free_disk_spaces.to_a }

    subject(:creator) { described_class.new(fake_devicegraph) }

    let(:scenario) { "spaces_3_8_two_disks" }

    it "creates the partitions honouring the distribution" do
      space3 = disk_spaces.detect { |s| s.disk_size == (3.GiB - 1.MiB) }
      space8 = disk_spaces.detect { |s| s.disk_size == (8.GiB - 1.MiB) }
      distribution = space_dist(
        space3 => [root_part, home_part],
        space8 => [swap_part]
      )

      result = creator.create_partitions(distribution)
      sda = result.disks.with(name: "/dev/sda")
      sdb = result.disks.with(name: "/dev/sdb")

      expect(sda.partitions).to contain_exactly(
        an_object_with_fields(mountpoint: "/"),
        an_object_with_fields(mountpoint: "/home"),
        an_object_with_fields(mountpoint: nil)
      )
      expect(sdb.partitions).to contain_exactly(
        an_object_with_fields(mountpoint: "swap"),
        an_object_with_fields(mountpoint: nil)
      )
    end

    context "when filling a space with several partitions" do
      let(:scenario) { "empty_hard_disk_mbr_50GiB" }
      let(:distribution) do
        space_dist(disk_spaces.first => [root_part, home_part, swap_part])
      end

      context "if the exact space is available" do
        before do
          root_part.disk_size = 20.GiB
          home_part.disk_size = 20.GiB
          swap_part.disk_size = 10.GiB - 1.MiB
        end

        it "creates partitions matching the proposed partitions sizes" do
          result = creator.create_partitions(distribution)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(mountpoint: "/", size: 20.GiB.to_i),
            an_object_with_fields(mountpoint: "/home", size: 20.GiB.to_i),
            an_object_with_fields(mountpoint: "swap", size: (10.GiB - 1.MiB).to_i)
          )
        end
      end

      context "if some extra space is available" do
        before do
          root_part.disk_size = 20.GiB
          root_part.weight = 1
          home_part.disk_size = 20.GiB
          home_part.weight = 2
          swap_part.disk_size = 1.GiB - 1.MiB
          swap_part.max = 1.GiB - 1.MiB
          swap_part.weight = 0
        end

        it "distributes the extra space" do
          result = creator.create_partitions(distribution)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(mountpoint: "/", size: 23.GiB.to_i),
            an_object_with_fields(mountpoint: "/home", size: 26.GiB.to_i),
            an_object_with_fields(mountpoint: "swap", size: (1.GiB - 1.MiB).to_i)
          )
        end

        context "if one of the proposed partitions is small" do
          before do
            swap_part.disk_size = 256.KiB
          end

          # In the past, the adjustments introduced by alignment caused the
          # other partitions to exhaust all the usable space, so the small
          # partition couldn't be created
          it "does not exhaust the space" do
            result = creator.create_partitions(distribution)
            expect(result.partitions).to contain_exactly(
              an_object_with_fields(mountpoint: "/"),
              an_object_with_fields(mountpoint: "/home"),
              an_object_with_fields(mountpoint: "swap")
            )
          end

          it "grows the small partition until the end of the slot" do
            result = creator.create_partitions(distribution)
            partition = result.partitions.with(id: Storage::ID_SWAP).first
            expect(partition.size).to eq 1.MiB.to_i
          end
        end
      end

      context "when the space is not divisible by the minimal grain" do
        # The last 16.5KiB of GPT are not usable, which makes the space not
        # divisible by 1MiB
        let(:scenario) { "empty_hard_disk_gpt_25GiB" }
        let(:partition1) do
          proposed_partition(mount_point: "/1", type: :vfat, disk_size: partition1_size, weight: 1)
        end
        let(:partition2) do
          proposed_partition(mount_point: "/2", type: :ext4, disk_size: 20.GiB, weight: 1)
        end
        let(:partition1_size) { 2.GiB }
        let(:distribution) { space_dist(disk_spaces.first => vols_list(partition1, partition2)) }

        it "fills the whole space if possible" do
          result = creator.create_partitions(distribution)
          expect(result.free_disk_spaces).to be_empty
        end

        context "if it's necessary to enforce a partition order" do
          let(:partition1_size) { disk_spaces.first.disk_size - 20.GiB - 256.KiB }

          it "fills the whole space if possible" do
            result = creator.create_partitions(distribution)
            expect(result.free_disk_spaces).to be_empty
          end

          it "places the required partition at the end" do
            result = creator.create_partitions(distribution)
            expect(result.partitions.last.filesystem.type).to eq Storage::FsType_VFAT
          end
        end
      end
    end

    context "when creating partitions in an empty space" do
      let(:scenario) { "space_22" }
      let(:distribution) do
        space_dist(disk_spaces.first => [root_part, home_part])
      end

      context "if the space should have no logical partitions" do
        before do
          allow(distribution.spaces.first).to receive(:num_logical).and_return 0
        end

        it "creates all partitions as primary" do
          result = creator.create_partitions(distribution)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda1"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda2"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, mountpoint: "/"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, mountpoint: "/home")
          )
        end
      end

      context "if all the partitions in the space must be logical" do
        before do
          space = distribution.spaces.first
          allow(space).to receive(:num_logical).and_return space.partitions.size
        end

        it "creates no new primary partitions" do
          result = creator.create_partitions(distribution)
          primary = result.partitions.with(type: ::Storage::PartitionType_PRIMARY)
          expect(primary).to contain_exactly(
            an_object_with_fields(name: "/dev/sda1", size: 78.GiB.to_i),
            an_object_with_fields(name: "/dev/sda2", size: (100.GiB - 1.MiB).to_i)
          )
        end

        it "creates an extended partition filling the whole space" do
          result = creator.create_partitions(distribution)
          extended = result.partitions.with(type: ::Storage::PartitionType_EXTENDED)
          expect(extended).to contain_exactly(
            an_object_with_fields(name: "/dev/sda3", size: 22.GiB.to_i)
          )
        end

        it "creates all the partitions as logical" do
          result = creator.create_partitions(distribution)
          logical = result.partitions.with(type: ::Storage::PartitionType_LOGICAL)
          expect(logical).to contain_exactly(
            an_object_with_fields(name: "/dev/sda5", size: 1.GiB.to_i),
            an_object_with_fields(name: "/dev/sda6", size: 1.GiB.to_i)
          )
        end
      end

      context "if the space must mix logical and primary partitions" do
        before do
          space = distribution.spaces.first
          allow(space).to receive(:num_logical).and_return(space.partitions.size - 1)
        end

        it "creates as many primary partitions as needed" do
          result = creator.create_partitions(distribution)
          primary = result.partitions.with(type: ::Storage::PartitionType_PRIMARY)
          expect(primary).to contain_exactly(
            an_object_with_fields(name: "/dev/sda1", size: 78.GiB.to_i),
            an_object_with_fields(name: "/dev/sda2", size: (100.GiB - 1.MiB).to_i),
            an_object_with_fields(name: "/dev/sda3", size: 1.GiB.to_i)
          )
        end

        it "creates an extended partition filling the remaining space" do
          result = creator.create_partitions(distribution)
          extended = result.partitions.with(type: ::Storage::PartitionType_EXTENDED)
          expect(extended).to contain_exactly(
            an_object_with_fields(name: "/dev/sda4", size: 21.GiB.to_i)
          )
        end

        it "creates logical partitions for the remaining proposed partitions" do
          result = creator.create_partitions(distribution)
          logical = result.partitions.with(type: ::Storage::PartitionType_LOGICAL)
          expect(logical).to contain_exactly an_object_with_fields(name: "/dev/sda5", size: 1.GiB.to_i)
        end
      end
    end

    context "when creating partitions within an existing extended one" do
      let(:scenario) { "space_22_extended" }
      let(:distribution) do
        space_dist(disk_spaces.first => [root_part, home_part])
      end

      before do
        space = distribution.spaces.first
        allow(space).to receive(:num_logical).and_return space.partitions.size
      end

      it "reuses the extended partition" do
        result = creator.create_partitions(distribution)
        extended = result.partitions.with(type: ::Storage::PartitionType_EXTENDED)
        expect(extended).to contain_exactly(
          an_object_with_fields(name: "/dev/sda4", size: (22.GiB - 1.MiB).to_i)
        )
      end

      it "creates all the partitions as logical" do
        result = creator.create_partitions(distribution)
        logical = result.partitions.with(type: ::Storage::PartitionType_LOGICAL)
        expect(logical).to contain_exactly(
          an_object_with_fields(name: "/dev/sda5", size: 1.GiB.to_i),
          an_object_with_fields(name: "/dev/sda6", size: 1.GiB.to_i)
        )
      end
    end

    context "when creating a partition" do
      let(:scenario) { "empty_hard_disk_mbr_50GiB" }
      let(:bootable) { false }

      let(:partition) do
        proposed_partition(
          type: :vfat, partition_id: Storage::ID_ESP, disk_size: 1.GiB, bootable: bootable
        )
      end
      let(:distribution) { space_dist(disk_spaces.first => [partition]) }

      it "correctly sets the libstorage partition id" do
        partition = creator.create_partitions(distribution).partitions.first
        expect(partition.id).to eq Storage::ID_ESP
      end

      it "formats the partition" do
        partition = creator.create_partitions(distribution).partitions.first
        expect(partition.filesystem.type).to eq Storage::FsType_VFAT
      end

      it "delegates the possible encryption to Encrypter" do
        encrypter = double("Y2Storage::Proposal::Encrypter")
        expect(Y2Storage::Proposal::Encrypter).to receive(:new).and_return encrypter

        expect(encrypter).to receive(:device_for) do |part, plain_device|
          expect(part).to have_attributes(
            partition_id: Storage::ID_ESP, disk_size: 1.GiB, bootable: bootable
          )
          expect(plain_device).to be_a(Storage::Partition)
          plain_device
        end

        creator.create_partitions(distribution)
      end

      context "if the partition must be encrypted" do
        before do
          partition.encryption_password = "s3cr3t"
        end

        it "formats the encrypted device instead of the plain partition" do
          partition = creator.create_partitions(distribution).partitions.first
          expect(partition.encryption.filesystem.type).to eq Storage::FsType_VFAT
        end
      end

      context "with a MBR partition table" do
        it "keeps the existing partition table" do
          old_table = fake_devicegraph.disks.first.partition_table
          result = creator.create_partitions(distribution)
          new_table = result.disks.first.partition_table

          expect(new_table.type).to eq Storage::PtType_MSDOS
          expect(new_table).to eq old_table
        end

        context "if the proposed partition is bootable" do
          let(:bootable) { true }

          it "sets the boot flag" do
            partition = creator.create_partitions(distribution).partitions.first
            expect(partition.boot?).to eq true
          end

          it "does not set the legacy boot flag" do
            partition = creator.create_partitions(distribution).partitions.first
            expect(partition.legacy_boot?).to eq false
          end
        end

        context "if the proposed partition is not bootable" do
          it "does not set the boot flag" do
            partition = creator.create_partitions(distribution).partitions.first
            expect(partition.boot?).to eq false
          end

          it "does not set the legacy boot flag" do
            partition = creator.create_partitions(distribution).partitions.first
            expect(partition.legacy_boot?).to eq false
          end
        end
      end

      context "with a GPT partition table" do
        let(:scenario) { "empty_hard_disk_gpt_50GiB" }

        it "keeps the existing partition table" do
          old_table = fake_devicegraph.disks.first.partition_table
          result = creator.create_partitions(distribution)
          new_table = result.disks.first.partition_table

          expect(new_table.type).to eq Storage::PtType_GPT
          expect(new_table).to eq old_table
        end

        context "if the volume is bootable" do
          let(:bootable) { true }

          it "does not set the boot flag" do
            partition = creator.create_partitions(distribution).partitions.first
            expect(partition.boot?).to eq false
          end

          it "does not set the legacy boot flag" do
            partition = creator.create_partitions(distribution).partitions.first
            expect(partition.legacy_boot?).to eq false
          end
        end

        context "if the volume is not bootable" do
          it "does not set the boot flag" do
            partition = creator.create_partitions(distribution).partitions.first
            expect(partition.boot?).to eq false
          end

          it "does not set the legacy boot flag" do
            partition = creator.create_partitions(distribution).partitions.first
            expect(partition.legacy_boot?).to eq false
          end
        end
      end

      context "if there is no partition table in the disk" do
        let(:scenario) { "empty_hard_disk_50GiB" }

        it "creates a new partition table of the preferred type" do
          result = creator.create_partitions(distribution)
          table = result.disks.first.partition_table

          expect(table.type).to eq Storage::PtType_GPT
        end
      end
    end
  end
end
