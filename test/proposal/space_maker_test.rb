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
    subject(:maker) { described_class.new(fake_devicegraph, analyzer, settings) }

    context "if the disk is not big enough" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:required_size) { 60.GiB }

      it "raises a NoDiskSpaceError exception" do
        expect { maker.provide_space(required_size) }
          .to raise_error Yast::Storage::Proposal::NoDiskSpaceError
      end
    end

    context "if there are Windows and Linux partitions" do
      let(:scenario) { "windows-linux-multiboot-pc" }
      let(:required_size) { 100.GiB }

      it "deletes some of the linux ones" do
        result = maker.provide_space(required_size)
        # FIXME: the result is actually kind of suboptimal, there were no need
        # to delete the swap partition
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(label: "windows", size: 250.GiB)
        )
      end
    end

    context "if there is a Windows partition and no Linux ones" do
      let(:scenario) { "windows-pc" }
      let(:resize_info) do
        instance_double("::Storage::ResizeInfo", resize_ok: true, min_size_k: 730.GiB.size_k)
      end
      let(:windows_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

      before do
        allow(analyzer).to receive(:windows_partitions).and_return windows_partitions
        allow_any_instance_of(::Storage::Filesystem).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      context "with enough free space in the Windows partition" do
        let(:required_size) { 40.GiB }

        it "shrinks the Windows partition by the required size" do
          result = maker.provide_space(required_size)
          win_partition = result.partitions.with(name: "/dev/sda1").first
          expect(win_partition.size_k.kiB).to eq 740.GiB
        end

        it "leaves other partitions untouched" do
          result = maker.provide_space(required_size)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(label: "windows"),
            an_object_with_fields(label: "recovery", size: 20.GiB)
          )
        end
      end

      context "with no enough free space in the Windows partition" do
        let(:required_size) { 60.GiB }

        it "shrinks the Windows partition as much as possible" do
          result = maker.provide_space(required_size)
          win_partition = result.partitions.with(name: "/dev/sda1").first
          expect(win_partition.size_k.kiB).to eq 730.GiB
        end

        it "removes other partitions" do
          result = maker.provide_space(required_size)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(label: "windows")
          )
        end
      end
    end

    context "if there are two Windows partitions" do
      let(:scenario) { "double-windows-pc" }
      let(:resize_info) do
        instance_double("::Storage::ResizeInfo", resize_ok: true, min_size_k: 50.GiB.size_k)
      end
      let(:windows_partitions) do
        {
          "/dev/sda" => [analyzer_part("/dev/sda1")],
          "/dev/sdb" => [analyzer_part("/dev/sdb1")]
        }
      end

      before do
        settings.candidate_devices = ["/dev/sda", "/dev/sdb"]
        allow(analyzer).to receive(:windows_partitions).and_return windows_partitions
        allow_any_instance_of(::Storage::Filesystem).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      context "with at least one Windows partition having enough free space" do
        let(:required_size) { 20.GiB }

        it "shrinks the less full Windows partition as needed" do
          result = maker.provide_space(required_size)
          win2_partition = result.partitions.with(name: "/dev/sdb1").first
          expect(win2_partition.size_k.kiB).to eq 160.GiB
        end

        it "leaves other partitions untouched" do
          result = maker.provide_space(required_size)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(label: "windows1", size: 80.GiB),
            an_object_with_fields(label: "recovery1", size: 20.GiB),
            an_object_with_fields(label: "windows2"),
            an_object_with_fields(label: "recovery2", size: 20.GiB)
          )
        end
      end

      context "with no partition having enough free space by itself" do
        let(:required_size) { 140.GiB }

        it "shrinks the less full Windows partition as much as possible" do
          result = maker.provide_space(required_size)
          win2_partition = result.partitions.with(name: "/dev/sdb1").first
          expect(win2_partition.size_k.kiB).to eq 50.GiB
        end

        it "shrinks the other Windows partition as needed" do
          result = maker.provide_space(required_size)
          win1_partition = result.partitions.with(name: "/dev/sda1").first
          expect(win1_partition.size_k.kiB).to eq 70.GiB
        end

        it "leaves other partitions untouched" do
          result = maker.provide_space(required_size)
          expect(result.partitions).to contain_exactly(
            an_object_with_fields(label: "windows1"),
            an_object_with_fields(label: "recovery1", size: 20.GiB),
            an_object_with_fields(label: "windows2"),
            an_object_with_fields(label: "recovery2", size: 20.GiB)
          )
        end
      end
    end

    context "when forced to delete partitions" do
      let(:scenario) { "multi-linux-pc" }

      it "deletes the first partitions of the disk until reaching the goal" do
        result = maker.provide_space(100.GiB)
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda4", size: 900.GiB),
          an_object_with_fields(name: "/dev/sda5", size: 300.GiB),
          an_object_with_fields(name: "/dev/sda6", size: 600.GiB)
        )
      end

      it "doesn't delete partitions listed in the 'keep' argument" do
        result = maker.provide_space(100.GiB, keep: ["/dev/sda2"])
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda2", size: 60.GiB),
          an_object_with_fields(name: "/dev/sda4", size: 900.GiB),
          an_object_with_fields(name: "/dev/sda6", size: 600.GiB)
        )
      end

      it "raises a NoDiskSpaceError exception if deleting is not enough" do
        expect { maker.provide_space(980.GiB, keep: ["/dev/sda2"]) }
          .to raise_error Yast::Storage::Proposal::NoDiskSpaceError
      end

      # FIXME: Bug or feature? Anyways, we are planning to change how libstorage-ng
      # handles extended and logical partitions. Revisit this then
      it "doesn't delete empty extended partitions unless required" do
        result = maker.provide_space(800.GiB, keep: ["/dev/sda1", "/dev/sda2", "/dev/sda3"])
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda1", size: 4.GiB),
          an_object_with_fields(name: "/dev/sda2", size: 60.GiB),
          an_object_with_fields(name: "/dev/sda3", size: 60.GiB),
          an_object_with_fields(name: "/dev/sda4", size: 900.GiB)
        )
      end

      # FIXME: in fact, extended partitions has no special consideration. This
      # works only by a matter of luck. See FIXME above.
      it "deletes empty extended partitions if the space is needed" do
        result = maker.provide_space(900.GiB, keep: ["/dev/sda1", "/dev/sda2", "/dev/sda3"])
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda1", size: 4.GiB),
          an_object_with_fields(name: "/dev/sda2", size: 60.GiB),
          an_object_with_fields(name: "/dev/sda3", size: 60.GiB)
        )
      end

      # FIXME: We are planning to change how libstorage-ng handles extended and logical
      # partitions. Then it will be time to fix this bug
      it "has an UGLY BUG that deletes extended partitions leaving the logical there" do
        result = maker.provide_space(
          400.GiB,
          keep: ["/dev/sda1", "/dev/sda2", "/dev/sda3", "/dev/sda6"]
        )
        expect(result.partitions).to contain_exactly(
          an_object_with_fields(name: "/dev/sda1", size: 4.GiB),
          an_object_with_fields(name: "/dev/sda2", size: 60.GiB),
          an_object_with_fields(name: "/dev/sda3", size: 60.GiB),
          an_object_with_fields(name: "/dev/sda6", size: 600.GiB)
        )
      end
    end
  end
end
