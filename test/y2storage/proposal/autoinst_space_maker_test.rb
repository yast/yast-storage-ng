#!/usr/bin/env rspec
#
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

require_relative "../spec_helper"
require "y2storage/proposal/autoinst_space_maker"
require "y2storage/autoinst_issues/list"

describe Y2Storage::Proposal::AutoinstSpaceMaker do
  subject(:space_maker) { described_class.new(analyzer) }

  let(:analyzer) { Y2Storage::DiskAnalyzer.new(fake_devicegraph) }
  let(:scenario) { "lvm-two-vgs" }
  let(:partitioning_array) { [{ "device" => "/dev/sda", "use" => "all" }] }
  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(partitioning_array)
  end

  let(:planned_devices) { [] }
  let(:drives_map) do
    Y2Storage::Proposal::AutoinstDrivesMap.new(fake_devicegraph, partitioning, issues_list)
  end
  let(:planned_partition) do
    Y2Storage::Planned::Partition.new("/").tap { |p| p.reuse = "/dev/sda8" }
  end
  let(:planned_vg) do
    Y2Storage::Planned::LvmVg.new(volume_group_name: "vg0").tap { |p| p.reuse = "vg0" }
  end
  let(:issues_list) do
    Y2Storage::AutoinstIssues::List
  end

  before { fake_scenario(scenario) }

  describe "#cleaned_devicegraph" do
    context "when 'use' key is set to 'all'" do
      it "removes all partitions" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
        expect(devicegraph.partitions).to be_empty
      end

      it "does not remove the partition table" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
        devicegraph.partitions
        disk = Y2Storage::Disk.find_by_name(devicegraph, "/dev/sda")
        expect(disk.partition_table).to_not be_nil
      end

      context "and a partition will be reused" do
        let(:scenario) { "lvm-two-vgs" }
        let(:planned_devices) { [planned_partition] }

        it "keeps reused partitions" do
          devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
          expect(devicegraph.partitions).to contain_exactly(
            an_object_having_attributes("name" => "/dev/sda3"),
            an_object_having_attributes("name" => planned_partition.reuse)
          )
        end
      end

      context "and a volume group will be reused" do
        let(:scenario) { "lvm-two-vgs" }
        let(:planned_devices) { [planned_vg] }

        it "keeps the physical volumes" do
          devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
          expect(devicegraph.partitions).to contain_exactly(
            an_object_having_attributes("name" => "/dev/sda3"),
            an_object_having_attributes("name" => "/dev/sda5")
          )
          vg = devicegraph.lvm_vgs.first
          pv = vg.lvm_pvs.first
          expect(pv.blk_device.name).to eq("/dev/sda5")
        end
      end

      context "and a RAID device will be reused" do
        it "keeps the physical partition"
      end
    end

    context "when 'use' key is set to 'linux'" do
      let(:partitioning_array) { [{ "device" => "/dev/sda", "use" => "linux" }] }

      it "removes only Linux partitions" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
        expect(devicegraph.partitions).to contain_exactly(
          an_object_having_attributes(name: "/dev/sda1"),
          an_object_having_attributes(name: "/dev/sda2")
        )
      end

      context "and a partition will be reused" do
        let(:scenario) { "lvm-two-vgs" }
        let(:planned_devices) { [planned_partition] }

        it "keeps reused partitions" do
          devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
          expect(devicegraph.partitions).to contain_exactly(
            an_object_having_attributes("name" => "/dev/sda1"),
            an_object_having_attributes("name" => "/dev/sda2"),
            an_object_having_attributes("name" => "/dev/sda3"),
            an_object_having_attributes("name" => planned_partition.reuse)
          )
        end
      end

      context "and a volume group will be reused" do
        let(:scenario) { "lvm-two-vgs" }
        let(:planned_devices) { [planned_vg] }

        it "keeps the physical volumes" do
          devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
          expect(devicegraph.partitions).to contain_exactly(
            an_object_having_attributes("name" => "/dev/sda1"),
            an_object_having_attributes("name" => "/dev/sda2"),
            an_object_having_attributes("name" => "/dev/sda3"),
            an_object_having_attributes("name" => "/dev/sda5")
          )
          vg = devicegraph.lvm_vgs.first
          pv = vg.lvm_pvs.first
          expect(pv.blk_device.name).to eq("/dev/sda5")
        end
      end
    end

    context "when 'use' is set to a list of partition numbers" do
      let(:partitioning_array) { [{ "device" => "/dev/sda", "use" => "2,3" }] }

      it "removes specified partitions" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
        expect(devicegraph.partitions).to contain_exactly(
          an_object_having_attributes(name: "/dev/sda1")
        )
      end

      context "and a partition will be reused" do
        let(:scenario) { "lvm-two-vgs" }
        let(:planned_devices) { [planned_partition] }
        let(:partitioning_array) { [{ "device" => "/dev/sda", "use" => "2,3,4,5,6,7,8,9" }] }

        it "keeps reused partitions" do
          devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
          expect(devicegraph.partitions).to contain_exactly(
            an_object_having_attributes("name" => "/dev/sda1"),
            an_object_having_attributes("name" => "/dev/sda3"),
            an_object_having_attributes("name" => planned_partition.reuse)
          )
        end
      end

      context "and a volume group will be reused" do
        let(:scenario) { "lvm-two-vgs" }
        let(:planned_devices) { [planned_vg] }
        let(:partitioning_array) { [{ "device" => "/dev/sda", "use" => "2,3,4,5,6,7,8,9" }] }

        it "keeps the physical volumes" do
          devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
          expect(devicegraph.partitions).to contain_exactly(
            an_object_having_attributes("name" => "/dev/sda1"),
            an_object_having_attributes("name" => "/dev/sda3"),
            an_object_having_attributes("name" => "/dev/sda5")
          )
          vg = devicegraph.lvm_vgs.first
          pv = vg.lvm_pvs.first
          expect(pv.blk_device.name).to eq("/dev/sda5")
        end
      end
    end

    context "when 'use' is set to an invalid value" do
      let(:partitioning_array) { [{ "device" => "/dev/sda", "use" => "wrong-value" }] }

      it "does not remove any partition" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
        expect(devicegraph.partitions.size).to eq(8)
      end

      it "registers an issue" do
        subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)

        issue = subject.issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::InvalidValue) }
        expect(issue.attr).to eq(:use)
        expect(issue.value).to eq("wrong-value")
      end
    end

    context "when 'use' is missing" do
      let(:partitioning_array) { [{ "device" => "/dev/sda" }] }

      it "does not remove any partition" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
        expect(devicegraph.partitions.size).to eq(8)
      end

      it "registers an issue" do
        subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)

        issue = subject.issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingValue) }
        expect(issue.attr).to eq(:use)
      end
    end

    context "when 'initialize' key is set to true" do
      let(:partitioning_array) { [{ "device" => "/dev/sda", "initialize" => true }] }

      it "remove all partitions" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
        expect(devicegraph.partitions).to be_empty
      end

      it "removes the partitions table" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
        devicegraph.partitions
        disk = Y2Storage::Disk.find_by_name(devicegraph, "/dev/sda")
        expect(disk.partition_table).to be_nil
      end

      context "and some device will be used" do
        let(:scenario) { "lvm-two-vgs" }
        let(:planned_devices) { [planned_partition] }
        let(:planned_partition) do
          Y2Storage::Planned::Partition.new("/").tap { |p| p.reuse = "/dev/sda1" }
        end

        it "does not remove the partition table" do
          devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices)
          devicegraph.partitions
          disk = Y2Storage::Disk.find_by_name(devicegraph, "/dev/sda")
          expect(disk.partition_table).to_not be_nil
        end
      end
    end

    context "when some given drive does not exist" do
      let(:drives_map) { instance_double(Y2Storage::Proposal::AutoinstDrivesMap) }

      before do
        allow(drives_map).to receive(:each_pair).and_yield("/dev/sdx", {})
      end

      it "ignores the device" do
        expect { subject.cleaned_devicegraph(fake_devicegraph, drives_map, planned_devices) }
          .to_not raise_error
      end
    end
  end
end
