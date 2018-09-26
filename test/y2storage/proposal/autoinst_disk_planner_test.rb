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

require_relative "../spec_helper"
require "y2storage/proposal/autoinst_disk_planner"
Yast.import "Arch"

describe Y2Storage::Proposal::AutoinstDiskPlanner do
  using Y2Storage::Refinements::SizeCasts

  subject(:planner) { described_class.new(fake_devicegraph, issues_list) }

  let(:scenario) { "windows-linux-free-pc" }
  let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

  before do
    fake_scenario(scenario)
    Y2Storage::VolumeSpecification.clear_cache
  end

  describe "#planned_devices" do
    let(:drive) { Y2Storage::AutoinstProfile::DriveSection.new_from_hashes(disk) }

    let(:disk) do
      { "device" => "/dev/sda", "partitions" => [root_spec] }
    end

    let(:root_spec) do
      { "mount" => "/", "filesystem" => "ext4", "fstopt" => "ro,acl", "mkfs_options" => "-b 2048" }
    end

    context "specifying partition type" do
      context "when partition_type is set to 'primary'" do
        let(:root_spec) { { "mount" => "/", "size" => "max", "partition_type" => "primary" } }

        it "sets the planned device as 'primary'" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.primary).to eq(true)
        end
      end

      context "when partition_type is set to other value" do
        let(:root_spec) { { "mount" => "/", "size" => "max", "partition_type" => "logical" } }

        it "sets planned device as not 'primary'" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.primary).to eq(false)
        end
      end

      context "when partition_type is not set" do
        let(:root_spec) { { "mount" => "/", "size" => "max" } }

        it "does not set 'primary'" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.primary).to eq(false)
        end
      end
    end

    context "specifying size" do
      using Y2Storage::Refinements::SizeCasts

      let(:root_spec) do
        { "mount" => "/", "filesystem" => "ext4", "size" => size }
      end

      context "when only a number is given" do
        let(:disk_size) { Y2Storage::DiskSize.B(10) }
        let(:size) { "10" }

        it "sets the size according to that number and using unit B" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(disk_size)
          expect(root.max_size).to eq(disk_size)
        end
      end

      context "when a number+unit is given" do
        let(:disk_size) { 5.GiB }
        let(:size) { "5GB" }

        it "sets the size according to that number and using legacy_units" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(disk_size)
          expect(root.max_size).to eq(disk_size)
        end
      end

      context "when a percentage is given" do
        let(:disk_size) { 250.GiB }
        let(:size) { "50%" }

        it "sets the size according to the percentage" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(disk_size)
          expect(root.max_size).to eq(disk_size)
        end
      end

      context "when 'max' is given" do
        let(:size) { "max" }

        it "sets the size to 'unlimited'" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(Y2Storage::DiskSize.B(1))
          expect(root.max_size).to eq(Y2Storage::DiskSize.unlimited)
        end

        it "sets the weight to '1'" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.weight).to eq(1)
        end
      end

      context "when an invalid value is given" do
        let(:size) { "huh?" }

        it "registers an issue" do
          expect(issues_list).to be_empty
          planner.planned_devices(drive, "/dev/sda")
          issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::InvalidValue) }
          expect(issue.value).to eq("huh?")
          expect(issue.attr).to eq(:size)
          expect(issue.new_value).to eq(:skip)
        end
      end

      context "when 'auto' is given" do
        let(:size) { "max" } # FIXME: root_size

        let(:auto_spec) do
          { "mount" => "swap", "filesystem" => "swap", "size" => "auto" }
        end

        let(:disk) do
          { "device" => "/dev/sda", "partitions" => [root_spec, auto_spec] }
        end

        let(:settings) do
          instance_double(Y2Storage::ProposalSettings, volumes: volumes, format: :ng)
        end

        let(:volumes) { [] }

        before do
          allow(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
            .and_return(settings)
        end

        context "when min and max are defined in the control file" do
          let(:volumes) do
            [
              Y2Storage::VolumeSpecification.new(
                "mount_point" => "swap", "min_size" => "128MiB", "max_size" => "1GiB"
              )
            ]
          end

          it "sets min and max" do
            devices = planner.planned_devices(drive, "/dev/sda")
            swap = devices.find { |d| d.mount_point == "swap" }
            expect(swap.min_size).to eq(128.MiB)
            expect(swap.max_size).to eq(1.GiB)
          end
        end

        context "when no default values are defined in the control file" do
          let(:auto_spec) do
            { "mount" => "/home", "filesystem" => "ext4", "size" => "auto" }
          end

          it "ignores the device" do
            devices = planner.planned_devices(drive, "/dev/sda")
            home = devices.find { |d| d.mount_point == "/home" }
            expect(home).to be_nil
          end

          it "registers an issue" do
            expect(issues_list).to be_empty
            planner.planned_devices(drive, "/dev/sda")
            issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::InvalidValue) }
            expect(issue.value).to eq("auto")
            expect(issue.attr).to eq(:size)
          end

          context "and device will be used as swap" do
            let(:auto_spec) do
              { "mount" => "swap", "filesystem" => "swap", "size" => "auto" }
            end

            it "sets default values" do
              devices = planner.planned_devices(drive, "/dev/sda")
              swap = devices.find { |d| d.mount_point == "swap" }
              expect(swap.min_size).to eq(512.MiB)
              expect(swap.max_size).to eq(2.GiB)
            end
          end
        end
      end

      context "when empty entry is given" do
        let(:size) { "" }

        it "sets the size to 'unlimited'" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(Y2Storage::DiskSize.B(1))
          expect(root.max_size).to eq(Y2Storage::DiskSize.unlimited)
        end
      end
    end

    context "specifying filesystem options" do
      let(:disk) do
        { "device" => "/dev/sda", "use" => "all",
           "partitions" => [root_spec, home_spec, swap_spec] }
      end

      let(:home_spec) do
        { "mount" => "/home", "filesystem" => "xfs", "mountby" => :uuid }
      end

      let(:swap_spec) do
        { "mount" => "swap" }
      end

      it "sets the filesystem" do
        devices = planner.planned_devices(drive, "/dev/sda")
        root = devices.find { |d| d.mount_point == "/" }
        home = devices.find { |d| d.mount_point == "/home" }
        expect(root.filesystem_type).to eq(Y2Storage::Filesystems::Type::EXT4)
        expect(home.filesystem_type).to eq(Y2Storage::Filesystems::Type::XFS)
      end

      context "when filesystem type is not specified" do
        let(:volspec_builder) do
          instance_double(Y2Storage::VolumeSpecificationBuilder, for: volspec)
        end
        let(:home_spec) { { "mount" => "/srv" } }
        let(:volspec) { Y2Storage::VolumeSpecification.new("fs_type" => "ext4") }

        before do
          allow(Y2Storage::VolumeSpecificationBuilder).to receive(:new)
            .and_return(volspec_builder)
        end

        it "sets to the default type for the given mount point" do
          expect(volspec_builder).to receive(:for).with("/srv").and_return(volspec)
          devices = planner.planned_devices(drive, "/dev/sda")
          srv = devices.find { |d| d.mount_point == "/srv" }
          expect(srv.filesystem_type).to eq(volspec.fs_type)
        end

        context "and no default is defined" do
          let(:volspec) { Y2Storage::VolumeSpecification.new({}) }

          it "sets filesystem to btrfs" do
            devices = planner.planned_devices(drive, "/dev/sda")
            srv = devices.find { |d| d.mount_point == "/srv" }
            expect(srv.filesystem_type).to eq(Y2Storage::Filesystems::Type::BTRFS)
          end

          context "and is a swap filesystem" do
            it "sets filesystem to swap" do
              devices = planner.planned_devices(drive, "/dev/sda")
              swap = devices.find { |d| d.mount_point == "swap" }
              expect(swap.filesystem_type).to eq(Y2Storage::Filesystems::Type::SWAP)
            end
          end
        end
      end

      it "sets the mountby properties" do
        devices = planner.planned_devices(drive, "/dev/sda")
        root = devices.find { |d| d.mount_point == "/" }
        home = devices.find { |d| d.mount_point == "/home" }
        expect(root.mount_by).to be_nil
        expect(home.mount_by).to eq(Y2Storage::Filesystems::MountByType::UUID)
      end

      it "sets fstab options" do
        devices = planner.planned_devices(drive, "/dev/sda")
        root = devices.find { |d| d.mount_point == "/" }
        expect(root.fstab_options).to eq(["ro", "acl"])
      end

      it "sets mkfs options" do
        devices = planner.planned_devices(drive, "/dev/sda")
        root = devices.find { |d| d.mount_point == "/" }
        expect(root.mkfs_options).to eq("-b 2048")
      end
    end

    context "specifying crypted partitions" do
      let(:root_spec) do
        { "mount" => "/", "filesystem" => "ext4", "crypt_fs" => true, "crypt_key" => "secret" }
      end

      it "sets the encryption password" do
        devices = planner.planned_devices(drive, "/dev/sda")
        root = devices.find { |d| d.mount_point == "/" }
        expect(root.encryption_password).to eq("secret")
      end
    end

    context "reusing partitions" do
      context "when a partition number is specified" do
        let(:scenario) { "autoyast_drive_examples" }

        let(:disk) do
          { "device" => "/dev/sdb", "partitions" => [root_spec] }
        end

        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => "ext4", "partition_nr" => 2 }
        end

        it "reuses the partition with that number" do
          devices = planner.planned_devices(drive, "/dev/sdb")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse_name).to eq("/dev/sdb2")
        end
      end

      context "when a partition label is specified" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => :ext4, "label" => "root" }
        end

        it "reuses the partition with that label" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse_name).to eq("/dev/sda3")
        end
      end

      context "when the partition to reuse does not exist" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => :ext4, "partition_nr" => 99 }
        end

        it "adds a new partition" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse_name).to be_nil
        end

        it "registers an issue" do
          expect(issues_list).to be_empty
          planner.planned_devices(drive, "/dev/sda")
          issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingReusableDevice) }
          expect(issue).to_not be_nil
        end
      end

      context "when no partition number or label is specified" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => :ext4 }
        end

        it "adds a new partition" do
          devices = planner.planned_devices(drive, "/dev/sda")
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse_name).to be_nil
        end

        it "registers an issue" do
          expect(issues_list).to be_empty
          planner.planned_devices(drive, "/dev/sda")
          issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingReuseInfo) }
          expect(issue).to_not be_nil
        end

        context "when formating but not mounting a partition" do
          let(:root_spec) do
            { "create" => false, "format" => true, "filesystem" => fs, "partition_nr" => 3 }
          end

          context "if the file system type is specified" do
            let(:fs) { "xfs" }

            it "plans the specified filesystem type" do
              devices = planner.planned_devices(drive, "/dev/sda")
              planned = devices.find { |d| d.reuse_name == "/dev/sda3" }
              expect(planned.reformat?).to eq true
              expect(planned.filesystem_type).to eq Y2Storage::Filesystems::Type::XFS
            end
          end

          context "if the file system type is not specified" do
            let(:fs) { nil }

            it "keeps the previous file system type of the partition" do
              devices = planner.planned_devices(drive, "/dev/sda")
              planned = devices.find { |d| d.reuse_name == "/dev/sda3" }
              expect(planned.reformat?).to eq true
              expect(planned.filesystem_type).to eq Y2Storage::Filesystems::Type::EXT4
            end
          end
        end
      end
    end

    context "when formatting but not mounting a Xen virtual partitions" do
      let(:scenario) { "xen-partitions.xml" }

      let(:disk) do
        { "device" => "/dev/xvda", "use" => "all", "partitions" => part_section }
      end

      context "if the file system type is specified" do
        let(:part_section) { [{ "partition_nr" => 2, "format" => true, "filesystem" => "ext2" }] }

        it "plans the specified filesystem type" do
          devices = planner.planned_devices(drive, "/dev/xdva")
          planned = devices.find { |d| d.reuse_name == "/dev/xvda2" }
          expect(planned.reformat?).to eq true
          expect(planned.filesystem_type).to eq Y2Storage::Filesystems::Type::EXT2
        end
      end

      context "if the file system type is not specified and there is a previous file system" do
        let(:part_section) { [{ "partition_nr" => 2, "format" => true }] }

        it "reuses the previous file system type" do
          devices = planner.planned_devices(drive, "/dev/xdva")
          planned = devices.find { |d| d.reuse_name == "/dev/xvda2" }
          expect(planned.reformat?).to eq true
          expect(planned.filesystem_type).to eq Y2Storage::Filesystems::Type::XFS
        end
      end

      context "if the file system type is not specified and there is no previous file system" do
        let(:part_section) { [{ "partition_nr" => 1, "format" => true }] }

        it "plans no filesystem type" do
          devices = planner.planned_devices(drive, "/dev/xdva")
          planned = devices.find { |d| d.reuse_name == "/dev/xvda1" }
          expect(planned.reformat?).to eq true
          expect(planned.filesystem_type).to be_nil
        end
      end
    end

  end
end
