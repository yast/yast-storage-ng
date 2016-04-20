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
require "storage/proposal"
require "storage/refinements/devicegraph_lists"
require "storage/refinements/size_casts"

describe Yast::Storage::Proposal::PartitionCreator do
  describe "#create_partitions" do
    using Yast::Storage::Refinements::SizeCasts
    using Yast::Storage::Refinements::DevicegraphLists

    before do
      fake_scenario(scenario)
      allow(Yast::Storage::Proposal::VolumesDispatcher).to receive(:new).and_return vol_dispatcher
      allow(vol_dispatcher).to receive(:distribution) do |volumes, spaces, _target|
        { spaces.first => volumes }
      end
    end

    let(:settings) do
      settings = Yast::Storage::Proposal::Settings.new
      settings.candidate_devices = ["/dev/sda"]
      settings.root_device = "/dev/sda"
      settings
    end
    let(:scenario) { "empty_hard_disk_50GiB" }
    let(:target_size) { :desired }

    let(:root_volume) { Yast::Storage::PlannedVolume.new("/", ::Storage::FsType_EXT4) }
    let(:home_volume) { Yast::Storage::PlannedVolume.new("/home", ::Storage::FsType_EXT4) }
    let(:swap_volume) { Yast::Storage::PlannedVolume.new("swap", ::Storage::FsType_EXT4) }
    let(:volumes) { Yast::Storage::PlannedVolumesList.new([root_volume, home_volume, swap_volume]) }
    let(:vol_dispatcher) { instance_double("Yast::Storage::Proposal::VolumesDispatcher") }

    subject(:creator) { described_class.new(fake_devicegraph, settings) }

    context "when the exact space is available" do
      before do
        root_volume.desired = 20.GiB
        home_volume.desired = 20.GiB
        swap_volume.desired = 10.GiB
      end

      it "creates partitions matching the volume sizes" do
        result = creator.create_partitions(volumes, target_size)
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(mountpoint: "/", size: 20.GiB),
          an_object_with_fields(mountpoint: "/home", size: 20.GiB),
          an_object_with_fields(mountpoint: "swap", size: 10.GiB)
        )
      end
    end

    context "when some extra space is available" do
      before do
        root_volume.desired = 20.GiB
        root_volume.weight = 1
        home_volume.desired = 20.GiB
        home_volume.weight = 2
        swap_volume.desired = 1.GiB
        swap_volume.max_size = 1.GiB
      end

      it "distributes the extra space" do
        result = creator.create_partitions(volumes, target_size)
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(mountpoint: "/", size: 23.GiB),
          an_object_with_fields(mountpoint: "/home", size: 26.GiB),
          an_object_with_fields(mountpoint: "swap", size: 1.GiB)
        )
      end
    end

    context "when there is no enough space to allocate start of all partitions" do
      before do
        root_volume.desired = 25.GiB
        home_volume.desired = 25.GiB
        swap_volume.desired = 10.GiB
      end

      it "raises an error" do
        expect { creator.create_partitions(volumes, target_size) }
          .to raise_error Yast::Storage::Proposal::Error
      end
    end

    context "when some volume is marked as 'reuse'" do
      before do
        root_volume.desired = 20.GiB
        home_volume.desired = 20.GiB
        swap_volume.reuse = "/dev/something"
        home_volume.weight = root_volume.weight = swap_volume.weight = 1
      end

      it "does not create the reused volumes" do
        result = creator.create_partitions(volumes, target_size)
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(mountpoint: "/"),
          an_object_with_fields(mountpoint: "/home")
        )
      end

      it "distributes extra space between the new (not reused) volumes" do
        result = creator.create_partitions(volumes, target_size)
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(size: 25.GiB),
          an_object_with_fields(size: 25.GiB)
        )
      end
    end

    context "when a ms-dos type partition is used" do
      before do
        root_volume.desired = 10.GiB
        home_volume.desired = 10.GiB
        swap_volume.desired = 2.GiB
      end

      context "when the only available space is in an extended partition" do
        let(:scenario) { "space_22_extended" }

        it "creates all partitions as logical" do
          result = creator.create_partitions(volumes, target_size)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda1"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda2"),
            an_object_with_fields(type: ::Storage::PartitionType_EXTENDED, name: "/dev/sda4"),
            an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda5"),
            an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda6"),
            an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda7")
          )
        end
      end

      context "when the only available space is completely unassigned" do
        let(:scenario) { "space_22" }

        it "creates primary/extended/logical partitions as needed" do
          result = creator.create_partitions(volumes, target_size)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda1"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda2"),
            an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda3"),
            an_object_with_fields(type: ::Storage::PartitionType_EXTENDED, name: "/dev/sda4"),
            an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda5"),
            an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda6")
          )
        end
      end
    end

    context "when there are several free spaces" do
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, desired: 1.GiB, max: 3.GiB, weight: 1) }
      let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, desired: 2.GiB, max: 3.GiB, weight: 1) }
      let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 3.GiB, max: 3.GiB) }
      let(:volumes) { Yast::Storage::PlannedVolumesList.new([vol1, vol2, vol3]) }

      context "if all the volumes fit in one space" do
        let(:scenario) { "spaces_5_6_8_10" }

        before do
          # TODO: Faking the desired dispatcher behavior
          allow(vol_dispatcher).to receive(:distribution) do |volumes, spaces, _target|
            {
              spaces[0] => Yast::Storage::PlannedVolumesList.new,
              spaces[1] => Yast::Storage::PlannedVolumesList.new,
              spaces[2] => volumes,
              spaces[3] => Yast::Storage::PlannedVolumesList.new
            }
          end
        end

        it "creates all the partitions in the same space" do
          result = creator.create_partitions(volumes, target_size)
          # FIXME: not the best check ever, we should actually check that the
          # new partitions live together
          expect(result.free_disk_spaces.size).to eq 3
        end

        it "uses the biggest space it can fill completely" do
          result = creator.create_partitions(volumes, target_size)
          sizes = result.free_disk_spaces.map { |s| s.size }
          expect(sizes.sort).to eq [5.GiB, 6.GiB, 10.GiB]
        end
      end

      context "if no single space is big enough" do
        context "and all the spaces are inside an extended partition" do
          let(:scenario) { "spaces_5_3_extended" }

          it "creates all partitions as logical" do
            result = creator.create_partitions(volumes, target_size)
            expect(result.partitions).to contain_exactly(
              an_object_with_fields(type: ::Storage::PartitionType_EXTENDED, name: "/dev/sda1"),
              an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda5"),
              an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda6"),
              an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda7"),
              an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda8"),
              an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda9")
            )
          end
        end

        context "and the spaces are unassigned (ms-dos partition table)" do
          let(:scenario) { "spaces_5_3" }

          it "creates primary/extended/logical partitions as needed" do
            # TODO: Faking the desired dispatcher behavior
            allow(vol_dispatcher).to receive(:distribution) do |volumes, spaces, _target|
              {
                spaces[0] => Yast::Storage::PlannedVolumesList.new([vol1, vol2]),
                spaces[1] => Yast::Storage::PlannedVolumesList.new([vol3])
              }
            end

            result = creator.create_partitions(volumes, target_size)
            expect(result.partitions).to contain_exactly(
              an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda1"),
              an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda2"),
              an_object_with_fields(type: ::Storage::PartitionType_EXTENDED, name: "/dev/sda3"),
              an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda5"),
              an_object_with_fields(type: ::Storage::PartitionType_LOGICAL, name: "/dev/sda6"),
              an_object_with_fields(type: ::Storage::PartitionType_PRIMARY, name: "/dev/sda4")
            )
          end
        end

        context "if it's possible to avoid gaps" do
          let(:scenario) { "spaces_5_3" }

          it "completely fills all the used spaces" do
            # TODO: Faking the desired dispatcher behavior
            allow(vol_dispatcher).to receive(:distribution) do |volumes, spaces, _target|
              {
                spaces[0] => Yast::Storage::PlannedVolumesList.new([vol1, vol2]),
                spaces[1] => Yast::Storage::PlannedVolumesList.new([vol3])
              }
            end

            result = creator.create_partitions(volumes, target_size)
            expect(result.free_disk_spaces).to be_empty
          end
        end

        context "if it's not possible to fill all the spaces" do
          let(:scenario) { "spaces_4_4" }

          it "creates the smallest possible gap" do
            # TODO: Faking the desired dispatcher behavior
            allow(vol_dispatcher).to receive(:distribution) do |volumes, spaces, _target|
              {
                spaces[0] => Yast::Storage::PlannedVolumesList.new([vol1, vol3]),
                spaces[1] => Yast::Storage::PlannedVolumesList.new([vol2])
              }
            end

            result = creator.create_partitions(volumes, target_size)
            spaces = result.free_disk_spaces
            expect(spaces.size).to eq 1
            # FIXME: I was actually expecting 1.GiB here, but it's not a big deal
            expect(spaces.first.size).to eq 1023.MiB
          end
        end
      end

      context "if disk restrictions apply to some volume" do
        before do
          vol3.disk = "/dev/sda"
          settings.candidate_devices = ["/dev/sda", "/dev/sdb"]
        end

        context "if a proper distribution is possible" do
          let(:scenario) { "spaces_5_1_two_disks" }

          before do
            # TODO: Faking the desired dispatcher behavior
            allow(vol_dispatcher).to receive(:distribution) do |volumes, spaces, _target|
              {
                spaces[0] => Yast::Storage::PlannedVolumesList.new([vol2, vol3]),
                spaces[1] => Yast::Storage::PlannedVolumesList.new([vol1])
              }
            end
          end

          it "honors the disk restrictions" do
            result = creator.create_partitions(volumes, target_size)
            sda1_parts = result.disks.with(name: "/dev/sda").partitions
            # This doesn't work properly with our SWIG objects
            # expect(sda1_parts).to include(an_object_with_fields(mountpoint: "/3"))
            sda1_mountpoints = sda1_parts.filesystems.map { |f| f.mountpoints.first }
            expect(sda1_mountpoints).to include "/3"
          end

          it "completely fills all the used spaces" do
            result = creator.create_partitions(volumes, target_size)
            expect(result.free_disk_spaces).to be_empty
          end
        end

        context "if the only way to avoid gaps is breaking the disk restrictions" do
          let(:scenario) { "spaces_3_8_two_disks" }

          before do
            # TODO: Faking the desired dispatcher behavior
            allow(vol_dispatcher).to receive(:distribution) do |volumes, spaces, _target|
              {
                spaces[0] => Yast::Storage::PlannedVolumesList.new([vol3]),
                spaces[1] => Yast::Storage::PlannedVolumesList.new([vol1, vol2])
              }
            end
          end

          it "honors the disk restrictions" do
            result = creator.create_partitions(volumes, target_size)
            sda1_parts = result.disks.with(name: "/dev/sda").partitions
            sda1_mountpoints = sda1_parts.filesystems.map { |f| f.mountpoints.first }
            expect(sda1_mountpoints).to include "/3"
          end

          it "creates the smallest possible gap" do
            result = creator.create_partitions(volumes, target_size)
            spaces = result.free_disk_spaces
            expect(spaces.size).to eq 1
            expect(spaces.first.size).to eq 2.GiB
          end
        end

        context "if is not possible to honor the disk restrictions" do
          let(:scenario) { "spaces_2_10_two_disks" }

          it "raises an error" do
            # TODO: Faking the desired dispatcher behavior
            allow(vol_dispatcher).to receive(:distribution)
              .and_raise Yast::Storage::Proposal::Error

            expect { creator.create_partitions(volumes, target_size) }
              .to raise_error Yast::Storage::Proposal::Error
          end
        end
      end
    end
  end
end
