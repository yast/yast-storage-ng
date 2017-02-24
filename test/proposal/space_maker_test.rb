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

describe Y2Storage::Proposal::SpaceMaker do
  describe "#make_space" do
    using Y2Storage::Refinements::SizeCasts
    using Y2Storage::Refinements::DevicegraphLists

    # Partition from fake_devicegraph, fetched by name
    def probed_partition(name)
      fake_devicegraph.partitions.with(name: name).first
    end

    before do
      fake_scenario(scenario)
      allow(analyzer).to receive(:windows_partitions).and_return windows_partitions
    end

    let(:settings) do
      settings = Y2Storage::ProposalSettings.new
      settings.candidate_devices = ["/dev/sda"]
      settings.root_device = "/dev/sda"
      settings
    end
    let(:proposed_partitions) { [partition1] }
    let(:keep) { [] }
    let(:analyzer) { Y2Storage::DiskAnalyzer.new(fake_devicegraph) }
    let(:lvm_helper) { Y2Storage::Proposal::LvmHelper.new([]) }
    let(:windows_partitions) { Hash.new }

    subject(:maker) { described_class.new(fake_devicegraph, analyzer, lvm_helper, settings) }

    context "if the only disk is not big enough" do
      let(:scenario) { "empty_hard_disk_mbr_50GiB" }
      let(:partition1) { proposed_partition(mount_point: "/1", type: :ext4, disk_size: 60.GiB) }

      it "raises a NoDiskSpaceError exception" do
        expect { maker.provide_space(proposed_partitions, partitions_to_keep: keep) }
          .to raise_error Y2Storage::Proposal::NoDiskSpaceError
      end
    end

    context "if the only disk has no partition table" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:partition1) { proposed_partition(mount_point: "/1", type: :ext4, disk_size: 40.GiB) }

      it "does not modify the disk" do
        result = maker.provide_space(proposed_partitions)
        disk = result[:devicegraph].disks.first
        expect(disk.has_partition_table).to eq false
      end

      it "assumes a (future) GPT partition table" do
        gpt_size = 1.MiB
        # The final 16.5 KiB are reserved by GPT
        gpt_final_space = 16.5.KiB

        result = maker.provide_space(proposed_partitions)
        space = result[:space_distribution].spaces.first
        expect(space.disk_size).to eq(50.GiB - gpt_size - gpt_final_space)
      end
    end

    context "with one disk containing Windows and Linux partitions" do
      let(:scenario) { "windows-linux-multiboot-pc" }
      let(:partition1) { proposed_partition(mount_point: "/1", type: :ext4, disk_size: 100.GiB) }
      let(:windows_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

      it "deletes linux partitions as needed" do
        result = maker.provide_space(proposed_partitions)
        expect(result[:devicegraph].partitions).to contain_exactly(
          an_object_with_fields(label: "windows", size: 250.GiB.to_i),
          an_object_with_fields(label: "swap", size: 2.GiB.to_i)
        )
      end

      it "stores the list of deleted partitions" do
        result = maker.provide_space(proposed_partitions)
        expect(result[:deleted_partitions]).to contain_exactly(
          an_object_with_fields(label: "root", size: (248.GiB - 1.MiB).to_i)
        )
      end

      it "suggests a distribution using the freed space" do
        result = maker.provide_space(proposed_partitions)
        distribution = result[:space_distribution]
        expect(distribution.spaces.size).to eq 1
        expect(distribution.spaces.first.partitions).to eq proposed_partitions
      end

      context "if deleting Linux is not enough" do
        let(:partition2) { proposed_partition(mount_point: "/2", type: :ext4, disk_size: 200.GiB) }
        let(:proposed_partitions) { [partition1, partition2] }
        let(:resize_info) do
          instance_double("::Storage::ResizeInfo", resize_ok: true, min_size: 100.GiB.to_i)
        end

        before do
          allow_any_instance_of(::Storage::BlkFilesystem).to receive(:detect_resize_info)
            .and_return(resize_info)
        end

        it "resizes Windows partitions to free additional needed space" do
          result = maker.provide_space(proposed_partitions)
          expect(result[:devicegraph].partitions).to contain_exactly(
            an_object_with_fields(label: "windows", size: (200.GiB - 1.MiB).to_i)
          )
        end
      end
    end

    context "with one disk containing a Windows partition and no Linux ones" do
      let(:scenario) { "windows-pc" }
      let(:resize_info) do
        instance_double("::Storage::ResizeInfo", resize_ok: true, min_size: 730.GiB.to_i)
      end
      let(:windows_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

      before do
        allow_any_instance_of(::Storage::BlkFilesystem).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      context "with enough free space in the Windows partition" do
        let(:partition1) { proposed_partition(mount_point: "/1", type: :ext4, disk_size: 40.GiB) }

        it "shrinks the Windows partition by the required size" do
          result = maker.provide_space(proposed_partitions)
          win_partition = result[:devicegraph].partitions.with(name: "/dev/sda1").first
          expect(win_partition.size).to eq 740.GiB.to_i
        end

        it "leaves other partitions untouched" do
          result = maker.provide_space(proposed_partitions)
          expect(result[:devicegraph].partitions).to contain_exactly(
            an_object_with_fields(label: "windows"),
            an_object_with_fields(label: "recovery", size: (20.GiB - 1.MiB).to_i)
          )
        end

        it "leaves empty the list of deleted partitions" do
          result = maker.provide_space(proposed_partitions)
          expect(result[:deleted_partitions]).to be_empty
        end

        it "suggests a distribution using the freed space" do
          result = maker.provide_space(proposed_partitions)
          distribution = result[:space_distribution]
          expect(distribution.spaces.size).to eq 1
          expect(distribution.spaces.first.partitions).to eq proposed_partitions
        end
      end

      context "with no enough free space in the Windows partition" do
        let(:partition1) { proposed_partition(mount_point: "/1", type: :ext4, disk_size: 60.GiB) }

        it "shrinks the Windows partition as much as possible" do
          result = maker.provide_space(proposed_partitions)
          win_partition = result[:devicegraph].partitions.with(name: "/dev/sda1").first
          expect(win_partition.size).to eq 730.GiB.to_i
        end

        it "removes other partitions" do
          result = maker.provide_space(proposed_partitions)
          expect(result[:devicegraph].partitions).to contain_exactly(
            an_object_with_fields(label: "windows")
          )
        end

        it "stores the list of deleted partitions" do
          result = maker.provide_space(proposed_partitions)
          expect(result[:deleted_partitions]).to contain_exactly(
            an_object_with_fields(label: "recovery", size: (20.GiB - 1.MiB).to_i)
          )
        end

        it "suggests a distribution using the freed space" do
          result = maker.provide_space(proposed_partitions)
          distribution = result[:space_distribution]
          expect(distribution.spaces.size).to eq 1
          expect(distribution.spaces.first.partitions).to eq proposed_partitions
        end
      end
    end

    context "if there are two Windows partitions" do
      let(:scenario) { "double-windows-pc" }
      let(:resize_info) do
        instance_double("::Storage::ResizeInfo", resize_ok: true, min_size: 50.GiB.to_i)
      end
      let(:windows_partitions) do
        {
          "/dev/sda" => [analyzer_part("/dev/sda1")],
          "/dev/sdb" => [analyzer_part("/dev/sdb1")]
        }
      end
      let(:partition1) { proposed_partition(mount_point: "/1", type: :ext4, disk_size: 20.GiB) }

      before do
        settings.candidate_devices = ["/dev/sda", "/dev/sdb"]
        allow_any_instance_of(::Storage::BlkFilesystem).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      it "shrinks first the less full Windows partition" do
        result = maker.provide_space(proposed_partitions)
        win2_partition = result[:devicegraph].partitions.with(name: "/dev/sdb1").first
        expect(win2_partition.size).to eq 160.GiB.to_i
      end

      it "leaves other partitions untouched if possible" do
        result = maker.provide_space(proposed_partitions)
        expect(result[:devicegraph].partitions).to contain_exactly(
          an_object_with_fields(label: "windows1", size: 80.GiB.to_i),
          an_object_with_fields(label: "recovery1", size: (20.GiB - 1.MiB).to_i),
          an_object_with_fields(label: "windows2"),
          an_object_with_fields(label: "recovery2", size: (20.GiB - 1.MiB).to_i)
        )
      end
    end

    context "when forced to delete partitions" do
      let(:scenario) { "multi-linux-pc" }

      it "deletes the last partitions of the disk until reaching the goal" do
        partition = proposed_partition(mount_point: "/1", type: :ext4, disk_size: 700.GiB)
        proposed_partitions = [partition]

        result = maker.provide_space(proposed_partitions)
        expect(result[:deleted_partitions]).to contain_exactly(
          an_object_with_fields(name: "/dev/sda4", size: (900.GiB - 1.MiB).to_i),
          an_object_with_fields(name: "/dev/sda5", size: 300.GiB.to_i),
          an_object_with_fields(name: "/dev/sda6", size: (600.GiB - 3.MiB).to_i)
        )
        expect(result[:devicegraph].partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda1", size: 4.GiB.to_i),
          an_object_with_fields(name: "/dev/sda2", size: 60.GiB.to_i),
          an_object_with_fields(name: "/dev/sda3", size: 60.GiB.to_i)
        )
      end

      it "doesn't delete partitions marked to be reused" do
        partition = proposed_partition(mount_point: "/1", type: :ext4, disk_size: 100.GiB)
        proposed_partitions = [partition]
        keep = ["/dev/sda6"]
        sda6 = probed_partition("/dev/sda6")

        result = maker.provide_space(proposed_partitions, partitions_to_keep: keep)
        expect(result[:devicegraph].partitions.map(&:sid)).to include sda6.sid
        expect(result[:deleted_partitions].map(&:sid)).to_not include sda6.sid
      end

      it "raises a NoDiskSpaceError exception if deleting is not enough" do
        partition = proposed_partition(mount_point: "/1", type: :ext4, disk_size: 980.GiB)
        proposed_partitions = [partition]
        keep = ["/dev/sda2"]

        expect { maker.provide_space(proposed_partitions, partitions_to_keep: keep) }.to(
          raise_error Y2Storage::Proposal::NoDiskSpaceError
        )
      end

      it "deletes extended partitions when deleting all its logical children" do
        partition = proposed_partition(mount_point: "/1", type: :ext4, disk_size: 800.GiB)
        proposed_partitions = [partition]
        keep = ["/dev/sda1", "/dev/sda2", "/dev/sda3"]

        result = maker.provide_space(proposed_partitions, partitions_to_keep: keep)
        expect(result[:devicegraph].partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda1", size: 4.GiB.to_i),
          an_object_with_fields(name: "/dev/sda2", size: 60.GiB.to_i),
          an_object_with_fields(name: "/dev/sda3", size: 60.GiB.to_i)
        )
        expect(result[:deleted_partitions]).to contain_exactly(
          an_object_with_fields(name: "/dev/sda4"),
          an_object_with_fields(name: "/dev/sda5"),
          an_object_with_fields(name: "/dev/sda6")
        )
      end

      # In the past, SpaceMaker used to delete the extended partition sda4
      # leaving sda6 alive. This test ensures the bug does not re-appear
      it "does not delete the extended partition if some logical one is to be reused" do
        partition = proposed_partition(mount_point: "/1", type: :ext4, disk_size: 400.GiB)
        proposed_partitions = [partition]
        keep = ["/dev/sda1", "/dev/sda2", "/dev/sda3", "/dev/sda6"]

        expect { maker.provide_space(proposed_partitions, partitions_to_keep: keep) }.to(
          raise_error Y2Storage::Proposal::NoDiskSpaceError
        )
      end
    end

    context "when some volumes must be reused" do
      let(:scenario) { "multi-linux-pc" }
      let(:proposed_partitions) do
        [
          proposed_partition(mount_point: "/1", type: :ext4, disk_size: 60.GiB),
          proposed_partition(mount_point: "/2", type: :ext4, disk_size: 300.GiB)
        ]
      end
      let(:keep) { ["/dev/sda6", "/dev/sda2"] } 

      before do
        skip("Do these tests make sense after adding partitions_to_keep parameter? ")
      end

      it "ignores reused partitions in the suggested distribution" do
        result = maker.provide_space(proposed_partitions, partitions_to_keep: keep)
        distribution = result[:space_distribution]
        dist_partitions = distribution.spaces.map { |s| s.partitions }.flatten
        expect(dist_partitions).to_not include an_object_with_fields(mount_point: "/3")
        expect(dist_partitions).to_not include an_object_with_fields(mount_point: "/4")
      end

      it "only makes space for non reused partitions" do
        result = maker.provide_space(proposed_partitions, partitions_to_keep: keep)
        freed_space = result[:devicegraph].free_disk_spaces.disk_size
        # Extra MiB for rounding issues
        expect(freed_space).to eq(360.GiB + 1.MiB)
      end
    end

    context "when some partitions have disk restrictions" do
      let(:scenario) { "mixed_disks" }
      let(:resize_info) do
        instance_double("::Storage::ResizeInfo", resize_ok: true, min_size: 50.GiB.to_i)
      end
      let(:windows_partitions) do
        { "/dev/sda" => [analyzer_part("/dev/sda1")] }
      end
      let(:partition1) { proposed_partition(mount_point: "/1", type: :ext4, disk: "/dev/sda") }
      let(:partition2) { proposed_partition(mount_point: "/2", type: :ext4, disk: "/dev/sda") }
      let(:partition3) { proposed_partition(mount_point: "/3", type: :ext4) }
      let(:proposed_partitions) { [partition1, partition2, partition3] }

      before do
        settings.candidate_devices = ["/dev/sda", "/dev/sdb"]
        allow_any_instance_of(::Storage::BlkFilesystem).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      context "if the choosen disk has no enough space" do
        before do
          partition1.disk_size = 101.GiB
          partition2.disk_size = 100.GiB
          partition3.disk_size = 1.GiB
        end

        it "raises an exception even if there is enough space in other disks" do
          expect { maker.provide_space(proposed_partitions) }.to raise_error Y2Storage::Proposal::Error
        end
      end

      context "if several disks can allocate the partitions" do
        before do
          partition1.disk_size = 60.GiB
          partition2.disk_size = 60.GiB
          partition3.disk_size = 1.GiB
        end

        it "ensures disk restrictions are honored" do
          result = maker.provide_space(proposed_partitions)
          distribution = result[:space_distribution]
          sda_space = distribution.spaces.detect { |sp| sp.disk_name == "/dev/sda" }
          # Without disk restrictions, it would have deleted linux partitions at /dev/sdb and
          # allocated the volumes there
          expect(sda_space.partitions).to include partition1
          expect(sda_space.partitions).to include partition2
        end

        it "applies the usual criteria to allocate non-restricted partitions" do
          result = maker.provide_space(proposed_partitions)
          distribution = result[:space_distribution]
          sdb_space = distribution.spaces.detect { |sp| sp.disk_name == "/dev/sdb" }
          # Default action: delete linux partitions at /dev/sdb and allocate volumes there
          expect(sdb_space.partitions).to include partition3
        end
      end
    end

    context "when deleting a partition which belongs to a LVM" do
      let(:scenario) { "lvm-two-vgs" }
      let(:windows_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }
      let(:proposed_partitions) { [proposed_partition(mount_point: "/1", type: :ext4, disk_size: 2.GiB)] }

      it "deletes also other partitions of the same volume group" do
        result = maker.provide_space(proposed_partitions)
        partitions = result[:devicegraph].partitions

        expect(partitions.map(&:sid)).to_not include probed_partition("/dev/sda9").sid
        expect(partitions.map(&:sid)).to_not include probed_partition("/dev/sda5").sid
      end

      it "deletes the volume group itself" do
        result = maker.provide_space(proposed_partitions)

        expect(result[:devicegraph].vgs.map(&:vg_name)).to_not include "vg1"
      end

      it "does not affect partitions from other volume groups" do
        result = maker.provide_space(proposed_partitions)
        devicegraph = result[:devicegraph]

        expect(devicegraph.partitions.map(&:name)).to include "/dev/sda7"
        expect(devicegraph.vgs.map(&:vg_name)).to include "vg0"
      end
    end

    context "when a LVM VG is going to be reused" do
      let(:scenario) { "lvm-two-vgs" }
      let(:windows_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }
      let(:resize_info) do
        instance_double("::Storage::ResizeInfo", resize_ok: true, min_size: 10.GiB.to_i)
      end
      # We are reusing vg1
      let(:keep) { ["/dev/sda9", "/dev/sda5"] }

      before do
        # We are reusing vg1
        # expect(lvm_helper).to receive(:partitions_in_vg).and_return ["/dev/sda5", "/dev/sda9"]
        # At some point, we can try to resize Windows
        allow_any_instance_of(::Storage::BlkFilesystem).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      it "does not delete partitions belonging to the reused VG" do
        proposed_partitions = [proposed_partition(mount_point: "/1", type: :ext4, disk_size: 2.GiB)]

        result = maker.provide_space(proposed_partitions, partitions_to_keep: keep)
        partitions = result[:devicegraph].partitions

        # sda5 and sda9 belong to vg1
        expect(partitions.map(&:sid)).to include probed_partition("/dev/sda9").sid
        expect(partitions.map(&:sid)).to include probed_partition("/dev/sda5").sid
        # sda8 is deleted instead of sda9
        expect(partitions.map(&:sid)).to_not include probed_partition("/dev/sda8").sid
      end

      it "does nothing special about partitions from other VGs" do
        proposed_partitions = [proposed_partition(mount_point: "/1", type: :ext4, disk_size: 6.GiB)]
        result = maker.provide_space(proposed_partitions, partitions_to_keep: keep)
        partitions = result[:devicegraph].partitions

        # sda7 belongs to vg0
        expect(partitions.map(&:sid)).to_not include probed_partition("/dev/sda7").sid
      end

      it "raises NoDiskSpaceError if it cannot find space respecting the VG" do
        proposed_partitions = [
          # This exhausts the primary partitions
          proposed_partition(mount_point: "/1", type: :ext4, disk_size: 30.GiB),
          # This implies deleting linux partitions out of vg1
          proposed_partition(mount_point: "/2", type: :ext4, disk_size: 14.GiB),
          # So this one, as small as it is, would affect vg1
          proposed_partition(mount_point: "/2", type: :ext4, disk_size: 10.MiB)
        ]
        expect { maker.provide_space(proposed_partitions, partitions_to_keep: keep) }
          .to raise_error Y2Storage::Proposal::NoDiskSpaceError
      end
    end
  end
end
