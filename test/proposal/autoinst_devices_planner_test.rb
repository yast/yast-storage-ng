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
require "y2storage/proposal/autoinst_devices_planner"

describe Y2Storage::Proposal::AutoinstDevicesPlanner do
  subject(:planner) { described_class.new(fake_devicegraph) }

  let(:scenario) { "windows-linux-free-pc" }
  let(:drives_map) { Y2Storage::Proposal::AutoinstDrivesMap.new(fake_devicegraph, partitioning) }
  let(:boot_checker) { instance_double(Y2Storage::BootRequirementsChecker, needed_partitions: []) }

  let(:partitioning) do
    [{ "device" => "/dev/sda", "partitions" => [root_spec] }]
  end

  let(:root_spec) { { "mount" => "/", "filesystem" => "ext4" } }

  before do
    allow(Y2Storage::BootRequirementsChecker).to receive(:new)
      .and_return(boot_checker)
    fake_scenario(scenario)
  end

  describe "#planned_devices" do
    context "when no partitions have been specified" do
      let(:partitioning) { [{ "device" => "/dev/sda" }] }

      it "raises an error" do
        expect { planner.planned_devices(drives_map) }.to raise_error(Y2Storage::Error)
      end
    end

    context "when a boot partition is required" do
      let(:boot) { Y2Storage::Planned::Partition.new("/boot", Y2Storage::Filesystems::Type::EXT4) }

      it "adds the boot partition" do
        expect(Y2Storage::BootRequirementsChecker).to receive(:new)
          .and_return(boot_checker)
        expect(boot_checker).to receive(:needed_partitions).and_return([boot])
        expect(planner.planned_devices(drives_map).map(&:mount_point)).to include("/boot")
      end
    end

    context "reusing partitions" do
      context "when a partition number is specified" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => "ext4", "partition_nr" => 3 }
        end

        it "reuses the partition with that number" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse).to eq("/dev/sda3")
        end
      end

      context "when a partition label is specified" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => "ext4", "label" => "root" }
        end

        it "reuses the partition with that label" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse).to eq("/dev/sda3")
        end
      end
    end

    context "specifying size" do
      using Y2Storage::Refinements::SizeCasts

      let(:root_spec) do
        { "mount" => "/", "filesystem" => "ext4", "size" => size }
      end

      context "when a number+unit is given" do
        let(:disk_size) { 5.GiB }
        let(:size) { "5GB" }

        it "sets the size according to that number and using legacy_units" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(disk_size)
          expect(root.max_size).to eq(disk_size)
        end
      end

      context "when a percentage is given" do
        let(:disk_size) { 250.GiB }
        let(:size) { "50%" }

        it "sets the size according to the percentage" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(disk_size)
          expect(root.max_size).to eq(disk_size)
        end
      end

      context "when 'max' is given" do
        let(:size) { "max" }

        it "sets the size to 'unlimited'" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(1.MiB)
          expect(root.max_size).to eq(Y2Storage::DiskSize.unlimited)
        end
      end
    end

    context "specifying filesystem" do
      let(:partitioning) do
        [{ "device" => "/dev/sda", "use" => "all", "partitions" => [root_spec, home_spec] }]
      end

      let(:home_spec) do
        { "mount" => "/home", "filesystem" => "xfs" }
      end

      it "sets the filesystem" do
        devices = planner.planned_devices(drives_map)
        root = devices.find { |d| d.mount_point == "/" }
        home = devices.find { |d| d.mount_point == "/home" }
        expect(root.filesystem_type).to eq(Y2Storage::Filesystems::Type::EXT4)
        expect(home.filesystem_type).to eq(Y2Storage::Filesystems::Type::XFS)
      end
    end

    context "specifying crypted partitions" do
      let(:root_spec) do
        { "mount" => "/", "filesystem" => "ext4", "crypt_fs" => true, "crypt_key" => "secret" }
      end

      it "sets the encryption password" do
        devices = planner.planned_devices(drives_map)
        root = devices.find { |d| d.mount_point == "/" }
        expect(root.encryption_password).to eq("secret")
      end
    end
  end
end
