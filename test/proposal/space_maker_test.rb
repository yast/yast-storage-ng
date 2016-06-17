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
require "storage/proposal"
require "storage/refinements/devicegraph_lists"
require "storage/refinements/size_casts"

describe Yast::Storage::Proposal::SpaceMaker do
  describe "#make_space" do
    using Yast::Storage::Refinements::SizeCasts
    using Yast::Storage::Refinements::DevicegraphLists

    before do
      fake_scenario(scenario)
    end

    let(:analyzer) do
      disk_analyzer = Yast::Storage::DiskAnalyzer.new
      disk_analyzer.analyze(fake_devicegraph)
      disk_analyzer
    end
    let(:settings) do
      settings = Yast::Storage::Proposal::Settings.new
      settings.candidate_devices = ["/dev/sda"]
      settings.root_device = "/dev/sda"
      settings
    end
    let(:volumes) { vols_list(vol1) }

    subject(:maker) { described_class.new(fake_devicegraph, analyzer, settings) }

    context "if the only disk is not big enough" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, desired: 60.GiB) }

      it "raises a NoDiskSpaceError exception" do
        expect { maker.provide_space(volumes) }
          .to raise_error Yast::Storage::Proposal::NoDiskSpaceError
      end
    end

    context "with one disk containing Windows and Linux partitions" do
      let(:scenario) { "windows-linux-multiboot-pc" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, desired: 100.GiB) }
      let(:windows_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

      before do
        allow(analyzer).to receive(:windows_partitions).and_return windows_partitions
      end

      it "deletes linux partitions as needed" do
        result = maker.provide_space(volumes)
        expect(result[:devicegraph].partitions).to contain_exactly(
          an_object_with_fields(label: "windows", size: 250.GiB.size_b),
          an_object_with_fields(label: "swap", size: 2.GiB.size_b)
        )
      end

      it "stores the list of deleted partitions" do
        result = maker.provide_space(volumes)
        expect(result[:deleted_partitions]).to contain_exactly(
          an_object_with_fields(label: "root", size: (248.GiB - 1.MiB).size_b)
        )
      end

      it "suggests a distribution using the freed space" do
        result = maker.provide_space(volumes)
        distribution = result[:space_distribution]
        expect(distribution.spaces.size).to eq 1
        expect(distribution.spaces.first.volumes.to_a).to eq volumes.to_a
      end

      context "if deleting Linux is not enough" do
        let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, desired: 200.GiB) }
        let(:volumes) { vols_list(vol1, vol2) }
        let(:resize_info) do
          instance_double("::Storage::ResizeInfo", resize_ok: true, min_size: 100.GiB.size_b)
        end

        before do
          allow_any_instance_of(::Storage::Filesystem).to receive(:detect_resize_info)
            .and_return(resize_info)
        end

        it "resizes Windows partitions to free additional needed space" do
          result = maker.provide_space(volumes)
          expect(result[:devicegraph].partitions).to contain_exactly(
            an_object_with_fields(label: "windows", size: (200.GiB - 1.MiB).size_b)
          )
        end
      end
    end

    context "with one disk containing a Windows partition and no Linux ones" do
      let(:scenario) { "windows-pc" }
      let(:resize_info) do
        instance_double("::Storage::ResizeInfo", resize_ok: true, min_size: 730.GiB.size_b)
      end
      let(:windows_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

      before do
        allow(analyzer).to receive(:windows_partitions).and_return windows_partitions
        allow_any_instance_of(::Storage::Filesystem).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      context "with enough free space in the Windows partition" do
        let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, desired: 40.GiB) }

        it "shrinks the Windows partition by the required size" do
          result = maker.provide_space(volumes)
          win_partition = result[:devicegraph].partitions.with(name: "/dev/sda1").first
          expect(win_partition.size).to eq 740.GiB.size_b
        end

        it "leaves other partitions untouched" do
          result = maker.provide_space(volumes)
          expect(result[:devicegraph].partitions).to contain_exactly(
            an_object_with_fields(label: "windows"),
            an_object_with_fields(label: "recovery", size: (20.GiB - 1.MiB).size_b)
          )
        end

        it "leaves empty the list of deleted partitions" do
          result = maker.provide_space(volumes)
          expect(result[:deleted_partitions]).to be_empty
        end

        it "suggests a distribution using the freed space" do
          result = maker.provide_space(volumes)
          distribution = result[:space_distribution]
          expect(distribution.spaces.size).to eq 1
          expect(distribution.spaces.first.volumes.to_a).to eq volumes.to_a
        end
      end

      context "with no enough free space in the Windows partition" do
        let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, desired: 60.GiB) }

        it "shrinks the Windows partition as much as possible" do
          result = maker.provide_space(volumes)
          win_partition = result[:devicegraph].partitions.with(name: "/dev/sda1").first
          expect(win_partition.size).to eq 730.GiB.size_b
        end

        it "removes other partitions" do
          result = maker.provide_space(volumes)
          expect(result[:devicegraph].partitions).to contain_exactly(
            an_object_with_fields(label: "windows")
          )
        end

        it "stores the list of deleted partitions" do
          result = maker.provide_space(volumes)
          expect(result[:deleted_partitions]).to contain_exactly(
            an_object_with_fields(label: "recovery", size: (20.GiB - 1.MiB).size_b)
          )
        end

        it "suggests a distribution using the freed space" do
          result = maker.provide_space(volumes)
          distribution = result[:space_distribution]
          expect(distribution.spaces.size).to eq 1
          expect(distribution.spaces.first.volumes.to_a).to eq volumes.to_a
        end
      end
    end

    context "if there are two Windows partitions" do
      let(:scenario) { "double-windows-pc" }
      let(:resize_info) do
        instance_double("::Storage::ResizeInfo", resize_ok: true, min_size: 50.GiB.size_b)
      end
      let(:windows_partitions) do
        {
          "/dev/sda" => [analyzer_part("/dev/sda1")],
          "/dev/sdb" => [analyzer_part("/dev/sdb1")]
        }
      end
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, desired: 20.GiB) }

      before do
        settings.candidate_devices = ["/dev/sda", "/dev/sdb"]
        allow(analyzer).to receive(:windows_partitions).and_return windows_partitions
        allow_any_instance_of(::Storage::Filesystem).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      it "shrinks first the less full Windows partition" do
        result = maker.provide_space(volumes)
        win2_partition = result[:devicegraph].partitions.with(name: "/dev/sdb1").first
        expect(win2_partition.size).to eq 160.GiB.size_b
      end

      it "leaves other partitions untouched if possible" do
        result = maker.provide_space(volumes)
        expect(result[:devicegraph].partitions).to contain_exactly(
          an_object_with_fields(label: "windows1", size: 80.GiB.size_b),
          an_object_with_fields(label: "recovery1", size: (20.GiB - 1.MiB).size_b),
          an_object_with_fields(label: "windows2"),
          an_object_with_fields(label: "recovery2", size: (20.GiB - 1.MiB).size_b)
        )
      end
    end

    context "when forced to delete partitions" do
      let(:scenario) { "multi-linux-pc" }

      it "deletes the last partitions of the disk until reaching the goal" do
        vol = planned_vol(mount_point: "/1", type: :ext4, desired: 700.GiB)
        volumes = vols_list(vol)

        result = maker.provide_space(volumes)
        expect(result[:deleted_partitions]).to contain_exactly(
          an_object_with_fields(name: "/dev/sda5", size: 300.GiB.size_b),
          an_object_with_fields(name: "/dev/sda6", size: (600.GiB - 3.MiB).size_b)
        )
        expect(result[:devicegraph].partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda1", size: 4.GiB.size_b),
          an_object_with_fields(name: "/dev/sda2", size: 60.GiB.size_b),
          an_object_with_fields(name: "/dev/sda3", size: 60.GiB.size_b),
          an_object_with_fields(name: "/dev/sda4", size: (900.GiB - 1.MiB).size_b)
        )
      end

      it "doesn't delete partitions marked to be reused" do
        vol1 = planned_vol(mount_point: "/1", type: :ext4, desired: 100.GiB)
        vol2 = planned_vol(mount_point: "/2", reuse: "/dev/sda6")
        volumes = vols_list(vol1, vol2)

        result = maker.provide_space(volumes)
        expect(result[:devicegraph].partitions.map(&:name)).to include "/dev/sda6"
        expect(result[:deleted_partitions].map(&:name)).to_not include "/dev/sda6"
      end

      it "raises a NoDiskSpaceError exception if deleting is not enough" do
        vol1 = planned_vol(mount_point: "/1", type: :ext4, desired: 980.GiB)
        vol2 = planned_vol(mount_point: "/2", reuse: "/dev/sda2")
        volumes = vols_list(vol1, vol2)

        expect { maker.provide_space(volumes) }.to raise_error Yast::Storage::Proposal::NoDiskSpaceError
      end

      # FIXME: Bug or feature? Anyways, we are planning to change how libstorage-ng
      # handles extended and logical partitions. Revisit this then
      it "doesn't delete empty extended partitions unless required" do
        volumes = vols_list(
          planned_vol(mount_point: "/1", type: :ext4, desired: 800.GiB),
          planned_vol(mount_point: "/2", reuse: "/dev/sda1"),
          planned_vol(mount_point: "/2", reuse: "/dev/sda2"),
          planned_vol(mount_point: "/2", reuse: "/dev/sda3")
        )

        result = maker.provide_space(volumes)
        expect(result[:devicegraph].partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda1", size: 4.GiB.size_b),
          an_object_with_fields(name: "/dev/sda2", size: 60.GiB.size_b),
          an_object_with_fields(name: "/dev/sda3", size: 60.GiB.size_b),
          an_object_with_fields(name: "/dev/sda4", size: (900.GiB - 1.MiB).size_b)
        )
        expect(result[:deleted_partitions]).to contain_exactly(
          an_object_with_fields(name: "/dev/sda5"),
          an_object_with_fields(name: "/dev/sda6")
        )
      end

      # FIXME: in fact, extended partitions has no special consideration. This
      # works only by a matter of luck. See FIXME above.
      it "deletes empty extended partitions if the space is needed" do
        volumes = vols_list(
          planned_vol(mount_point: "/1", type: :ext4, desired: (900.GiB - 1.MiB)),
          planned_vol(mount_point: "/2", reuse: "/dev/sda1"),
          planned_vol(mount_point: "/2", reuse: "/dev/sda2"),
          planned_vol(mount_point: "/2", reuse: "/dev/sda3")
        )

        result = maker.provide_space(volumes)
        expect(result[:devicegraph].partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda1", size: 4.GiB.size_b),
          an_object_with_fields(name: "/dev/sda2", size: 60.GiB.size_b),
          an_object_with_fields(name: "/dev/sda3", size: 60.GiB.size_b)
        )
        expect(result[:deleted_partitions]).to contain_exactly(
          an_object_with_fields(name: "/dev/sda4"),
          an_object_with_fields(name: "/dev/sda5"),
          an_object_with_fields(name: "/dev/sda6")
        )
      end

      # FIXME: We are planning to change how libstorage-ng handles extended and logical
      # partitions. Then it will be time to fix this bug
      it "has an UGLY BUG that deletes extended partitions leaving the logical there" do
        volumes = vols_list(
          planned_vol(mount_point: "/1", type: :ext4, desired: 400.GiB),
          planned_vol(mount_point: "/2", reuse: "/dev/sda1"),
          planned_vol(mount_point: "/3", reuse: "/dev/sda2"),
          planned_vol(mount_point: "/4", reuse: "/dev/sda3"),
          planned_vol(mount_point: "/5", reuse: "/dev/sda6")
        )

        result = maker.provide_space(volumes)
        expect(result[:devicegraph].partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda1", size: 4.GiB.size_b),
          an_object_with_fields(name: "/dev/sda2", size: 60.GiB.size_b),
          an_object_with_fields(name: "/dev/sda3", size: 60.GiB.size_b),
          an_object_with_fields(name: "/dev/sda6", size: (600.GiB - 3.MiB).size_b)
        )
      end
    end

    context "when some volumes must be reused" do
      let(:scenario) { "multi-linux-pc" }
      let(:volumes) do
        vols_list(
          planned_vol(mount_point: "/1", type: :ext4, desired: 60.GiB),
          planned_vol(mount_point: "/2", type: :ext4, desired: 300.GiB),
          planned_vol(mount_point: "/3", reuse: "/dev/sda6"),
          planned_vol(mount_point: "/4", reuse: "/dev/sda2")
        )
      end

      it "ignores reused partitions in the suggested distribution" do
        result = maker.provide_space(volumes)
        distribution = result[:space_distribution]
        dist_volumes = distribution.spaces.map { |s| s.volumes.to_a }.flatten
        expect(dist_volumes).to_not include an_object_with_fields(mount_point: "/3")
        expect(dist_volumes).to_not include an_object_with_fields(mount_point: "/4")
      end

      it "only makes space for non reused volumes" do
        result = maker.provide_space(volumes)
        freed_space = result[:devicegraph].free_disk_spaces.disk_size
        # Extra MiB for rounding issues
        expect(freed_space).to eq(360.GiB + 1.MiB)
      end
    end

    context "when some volumes have disk restrictions" do
      let(:scenario) { "mixed_disks" }
      let(:resize_info) do
        instance_double("::Storage::ResizeInfo", resize_ok: true, min_size: 50.GiB.size_b)
      end
      let(:windows_partitions) do
        { "/dev/sda" => [analyzer_part("/dev/sda1")] }
      end
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, disk: "/dev/sda") }
      let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, disk: "/dev/sda") }
      let(:vol3) { planned_vol(mount_point: "/3", type: :ext4) }
      let(:volumes) { vols_list(vol1, vol2, vol3) }

      before do
        settings.candidate_devices = ["/dev/sda", "/dev/sdb"]
        allow(analyzer).to receive(:windows_partitions).and_return windows_partitions
        allow_any_instance_of(::Storage::Filesystem).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      context "if the choosen disk has no enough space" do
        before do
          vol1.desired = 101.GiB
          vol2.desired = 100.GiB
          vol3.desired = 1.GiB
        end

        it "raises an exception even if there is enough space in other disks" do
          expect { maker.provide_space(volumes) }.to raise_error Yast::Storage::Proposal::Error
        end
      end

      context "if several disks can allocate the volumes" do
        before do
          vol1.desired = 60.GiB
          vol2.desired = 60.GiB
          vol3.desired = 1.GiB
        end

        it "ensures disk restrictions are honored" do
          result = maker.provide_space(volumes)
          distribution = result[:space_distribution]
          sda_space = distribution.spaces.detect { |i| i.disk_name == "/dev/sda" }
          # Without disk restrictions, it would have deleted linux partitions at /dev/sdb and
          # allocated the volumes there
          expect(sda_space.volumes).to include vol1
          expect(sda_space.volumes).to include vol2
        end

        it "applies the usual criteria to allocate non-restricted volumes" do
          result = maker.provide_space(volumes)
          distribution = result[:space_distribution]
          sdb_space = distribution.spaces.detect { |i| i.disk_name == "/dev/sdb" }
          # Default action: delete linux partitions at /dev/sdb and allocate volumes there
          expect(sdb_space.volumes).to include vol3
        end
      end
    end
  end
end
