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
require "storage"
require "y2storage"

Yast.import "ProductFeatures"

describe Y2Storage::GuidedProposal do
  using Y2Storage::Refinements::SizeCasts

  def select_partition(mount_point, partitions)
    partitions.find { |p| p.filesystem_mountpoint == mount_point }
  end

  def expect_found_all_partitions_at(disk)
    expect(disk.partitions).to contain_exactly(
      an_object_having_attributes(id: Y2Storage::PartitionId::BIOS_BOOT),
      an_object_having_attributes(filesystem_mountpoint: "/"),
      an_object_having_attributes(filesystem_mountpoint: "/home"),
      an_object_having_attributes(filesystem_mountpoint: "swap")
    )
  end

  before do
    Yast::ProductFeatures.Import(
      "partitioning" => {
        "proposal" => [],
        "volumes"  => volumes_features
      }
    )
    Y2Storage::StorageManager.create_test_instance
  end

  subject(:proposal) { described_class.new }
  let(:volumes_features) do
    [
      {
        "fs_type"      => "swap",
        "mount_point"  => "swap",
        "desired_size" => "1GiB",
        "min_size"     => "512MiB",
        "max_size"     => "2GiB"
      },
      {
        "fs_type"      => "ext4",
        "mount_point"  => "/",
        "desired_size" => "40GiB",
        "min_size"     => "20GiB",
        "max_size"     => "100GiB"
      },
      {
        "fs_type"      => "xfs",
        "mount_point"  => "/home",
        "desired_size" => "20GiB",
        "min_size"     => "10GiB",
        "max_size"     => "40GiB"
      }
    ]
  end

  describe "#propose" do
    context "with no candidate devices" do
      let(:needed_space_for_desired_sizes) { 65.GiB }
      let(:needed_space_for_min_sizes) { 35.GiB }
      let(:not_enough_size) { 20.GiB }

      context "in a system with a single disk" do
        before do
          create_empty_disk("/dev/sdc", disk_size)
        end

        context "having enough space for desired sizes" do
          let(:disk_size) { needed_space_for_desired_sizes }

          it "makes the proposal using desired sizes" do
            proposal.propose

            disk = proposal.devices.disks.first

            expect_found_all_partitions_at(disk)
            expect(select_partition("swap", disk.partitions).size).to eq(1.GiB)
            expect(select_partition("/", disk.partitions).size).to eq(40.GiB)
            expect(select_partition("/home", disk.partitions).size).to eq(20.GiB)
          end
        end

        context "having space only for minimum sizes" do
          let(:disk_size) { needed_space_for_min_sizes }

          it "makes the proposal using minimum sizes" do
            proposal.propose

            disk = proposal.devices.disks.first

            expect_found_all_partitions_at(disk)
            expect(select_partition("swap", disk.partitions).size).to eq(512.MiB)
            expect(select_partition("/", disk.partitions).size).to eq(20.GiB)
            expect(select_partition("/home", disk.partitions).size).to eq(10.GiB)
          end
        end

        context "without enough space" do
          let(:disk_size) { 10.GiB }

          it "raises an Y2Storage::Error" do
            expect { proposal.propose }.to raise_error(Y2Storage::Error)
          end
        end
      end

      context "in a system with multiple disks" do
        before do
          create_empty_disk("/dev/sdc", third_disk_size)
          create_empty_disk("/dev/sdb", second_disk_size)
          create_empty_disk("/dev/sda", first_disk_size)
        end

        context "having enough space for desired sizes" do
          let(:first_disk_size) { needed_space_for_desired_sizes }
          let(:second_disk_size) { needed_space_for_desired_sizes }
          let(:third_disk_size) { needed_space_for_desired_sizes }

          context "in all of them" do
            it "proposes to use the first one" do
              proposal.propose

              first_disk, second_disk, third_disk = proposal.devices.disks
              partitions = first_disk.partitions

              expect_found_all_partitions_at(first_disk)
              expect(second_disk.partitions).to be_empty
              expect(third_disk.partitions).to be_empty

              expect(select_partition("swap", partitions).size).to eq(1.GiB)
              expect(select_partition("/", partitions).size).to eq(40.GiB)
              expect(select_partition("/home", partitions).size).to eq(20.GiB)
            end
          end

          context "only in one of them" do
            let(:first_disk_size) { needed_space_for_min_sizes }
            let(:third_disk_size) { needed_space_for_min_sizes }

            it "proposes to use it" do
              proposal.propose

              first_disk, second_disk, third_disk = proposal.devices.disks
              partitions = second_disk.partitions

              expect_found_all_partitions_at(second_disk)
              expect(first_disk.partitions).to be_empty
              expect(third_disk.partitions).to be_empty

              expect(select_partition("swap", partitions).size).to eq(1.GiB)
              expect(select_partition("/", partitions).size).to eq(40.GiB)
              expect(select_partition("/home", partitions).size).to eq(20.GiB)
            end
          end

          context "in none of them individually but all together" do
            let(:first_disk_size) { 25.GiB }
            let(:second_disk_size) { 1.GiB }
            let(:third_disk_size) { 45.GiB }

            it "proposes to use all of them" do
              proposal.propose

              first_disk, second_disk, third_disk = proposal.devices.disks

              expect(first_disk.partitions).to_not be_empty
              expect(second_disk.partitions).to_not be_empty # boot partition
              expect(third_disk.partitions).to_not be_empty

              root_partition = select_partition("/", third_disk.partitions)
              home_partition = select_partition("/home", first_disk.partitions)
              swap_partition = select_partition("swap", first_disk.partitions)

              expect(root_partition).to_not be_nil
              expect(root_partition.size).to eq(40.GiB)

              expect(home_partition).to_not be_nil
              expect(home_partition.size).to eq(20.GiB)

              expect(swap_partition).to_not be_nil
              expect(swap_partition.size).to eq(1.GiB)
            end
          end
        end

        context "having space only for minimum sizes" do
          let(:first_disk_size) { needed_space_for_min_sizes }
          let(:second_disk_size) { needed_space_for_min_sizes }
          let(:third_disk_size) { needed_space_for_min_sizes }

          context "in all of them" do
            it "proposes to use the first one" do
              proposal.propose

              first_disk, second_disk, third_disk = proposal.devices.disks
              partitions = first_disk.partitions

              expect_found_all_partitions_at(first_disk)
              expect(second_disk.partitions).to be_empty
              expect(third_disk.partitions).to be_empty

              expect(select_partition("swap", partitions).size).to eq(512.MiB)
              expect(select_partition("/", partitions).size).to eq(20.GiB)
              expect(select_partition("/home", partitions).size).to eq(10.GiB)
            end
          end

          context "only in one of them" do
            let(:first_disk_size) { not_enough_size }
            let(:third_disk_size) { not_enough_size }

            it "proposes to use it" do
              proposal.propose

              first_disk, second_disk, third_disk = proposal.devices.disks

              expect(first_disk.partitions).to be_empty
              expect(third_disk.partitions).to be_empty
              expect_found_all_partitions_at(second_disk)

              partitions = second_disk.partitions
              root_partition = select_partition("/", partitions)
              home_partition = select_partition("/home", partitions)
              swap_partition = select_partition("swap", partitions)

              expect(root_partition).to_not be_nil
              expect(root_partition.size).to eq(20.GiB)

              expect(home_partition).to_not be_nil
              expect(home_partition.size).to eq(10.GiB)

              expect(swap_partition).to_not be_nil
              expect(swap_partition.size).to eq(512.MiB)
            end
          end

          context "in none of them individually but all together" do
            let(:first_disk_size) { 1.GiB }
            let(:second_disk_size) { 10.5.GiB }
            let(:third_disk_size) { 20.5.GiB }

            it "proposes to use all of them" do
              proposal.propose

              first_disk, second_disk, third_disk = proposal.devices.disks

              expect(first_disk.partitions).to_not be_empty
              expect(second_disk.partitions).to_not be_empty
              expect(third_disk.partitions).to_not be_empty

              root_partition = select_partition("/", third_disk.partitions)
              home_partition = select_partition("/home", second_disk.partitions)
              swap_partition = select_partition("swap", first_disk.partitions)

              expect(root_partition).to_not be_nil
              expect(root_partition.size).to eq(20.GiB)

              expect(home_partition).to_not be_nil
              expect(home_partition.size).to eq(10.GiB)

              expect(swap_partition).to_not be_nil
              expect(swap_partition.size).to eq(512.MiB)
            end
          end
        end

        context "too small for both (desired, min) proposals" do
          let(:first_disk_size) { not_enough_size }
          let(:second_disk_size) { not_enough_size }
          let(:third_disk_size) { not_enough_size }

          it "raises an Y2Storage::Error" do
            expect { proposal.propose }.to raise_error(Y2Storage::Error)
          end
        end
      end
    end
  end
end
