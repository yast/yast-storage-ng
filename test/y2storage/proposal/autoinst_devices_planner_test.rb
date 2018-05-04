#!/usr/bin/env rspec
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
require "y2storage/volume_specification"
require "y2storage/autoinst_issues/list"
Yast.import "Arch"

describe Y2Storage::Proposal::AutoinstDevicesPlanner do
  using Y2Storage::Refinements::SizeCasts

  subject(:planner) { described_class.new(fake_devicegraph, issues_list) }

  let(:scenario) { "windows-linux-free-pc" }
  let(:drives_map) do
    Y2Storage::Proposal::AutoinstDrivesMap.new(fake_devicegraph, partitioning, issues_list)
  end
  let(:boot_checker) { instance_double(Y2Storage::BootRequirementsChecker, needed_partitions: []) }
  let(:architecture) { :x86_64 }
  let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

  let(:partitioning_array) do
    [{ "device" => "/dev/sda", "partitions" => [root_spec] }]
  end

  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(partitioning_array)
  end

  let(:root_spec) do
    { "mount" => "/", "filesystem" => "ext4", "fstopt" => "ro,acl", "mkfs_options" => "-b 2048" }
  end

  let(:lvm_group) { "vg0" }

  before do
    allow(Y2Storage::BootRequirementsChecker).to receive(:new)
      .and_return(boot_checker)
    fake_scenario(scenario)

    # Do not read from running system
    allow(Yast::ProductFeatures).to receive(:GetSection).with("partitioning").and_return(nil)

    allow(Yast::Arch).to receive(:x86_64).and_return(architecture == :x86_64)
    allow(Yast::Arch).to receive(:i386).and_return(architecture == :i386)
    allow(Yast::Arch).to receive(:ppc).and_return(architecture == :ppc)
    allow(Yast::Arch).to receive(:s390).and_return(architecture == :s390)
    Y2Storage::VolumeSpecification.clear_cache
  end

  describe "#planned_devices" do
    context "reusing partitions" do
      context "when a partition number is specified" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => "ext4", "partition_nr" => 3 }
        end

        it "reuses the partition with that number" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse_name).to eq("/dev/sda3")
        end
      end

      context "when a partition label is specified" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => :ext4, "label" => "root" }
        end

        it "reuses the partition with that label" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse_name).to eq("/dev/sda3")
        end
      end

      context "when the partition to reuse does not exist" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => :ext4, "partition_nr" => 99 }
        end

        it "adds a new partition" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse_name).to be_nil
        end

        it "registers an issue" do
          expect(issues_list).to be_empty
          planner.planned_devices(drives_map)
          issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingReusableDevice) }
          expect(issue).to_not be_nil
        end
      end

      context "when no partition number or label is specified" do
        let(:root_spec) do
          { "create" => false, "mount" => "/", "filesystem" => :ext4 }
        end

        it "adds a new partition" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.reuse_name).to be_nil
        end

        it "registers an issue" do
          expect(issues_list).to be_empty
          planner.planned_devices(drives_map)
          issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingReuseInfo) }
          expect(issue).to_not be_nil
        end
      end
    end

    context "specifying partition type" do
      let(:root_spec) do
        { "mount" => "/", "size" => size, "partition_type" => "primary" }
      end

      context "when partition_type is set to 'primary'" do
        let(:root_spec) { { "mount" => "/", "size" => "max", "partition_type" => "primary" } }

        it "sets the planned device as 'primary'" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.primary).to eq(true)
        end
      end

      context "when partition_type is set to other value" do
        let(:root_spec) { { "mount" => "/", "size" => "max", "partition_type" => "logical" } }

        it "sets planned device as not 'primary'" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.primary).to eq(false)
        end
      end

      context "when partition_type is not set" do
        let(:root_spec) { { "mount" => "/", "size" => "max" } }

        it "does not set 'primary'" do
          devices = planner.planned_devices(drives_map)
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
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(disk_size)
          expect(root.max_size).to eq(disk_size)
        end
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
          expect(root.min_size).to eq(Y2Storage::DiskSize.B(1))
          expect(root.max_size).to eq(Y2Storage::DiskSize.unlimited)
        end

        it "sets the weight to '1'" do
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.weight).to eq(1)
        end
      end

      context "when an invalid value is given" do
        let(:size) { "huh?" }

        it "registers an issue" do
          expect(issues_list).to be_empty
          planner.planned_devices(drives_map)
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

        let(:partitioning_array) do
          [{ "device" => "/dev/sda", "partitions" => [root_spec, auto_spec] }]
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
            devices = planner.planned_devices(drives_map)
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
            devices = planner.planned_devices(drives_map)
            home = devices.find { |d| d.mount_point == "/home" }
            expect(home).to be_nil
          end

          it "registers an issue" do
            expect(issues_list).to be_empty
            planner.planned_devices(drives_map)
            issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::InvalidValue) }
            expect(issue.value).to eq("auto")
            expect(issue.attr).to eq(:size)
          end

          context "and device will be used as swap" do
            let(:auto_spec) do
              { "mount" => "swap", "filesystem" => "swap", "size" => "auto" }
            end

            it "sets default values" do
              devices = planner.planned_devices(drives_map)
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
          devices = planner.planned_devices(drives_map)
          root = devices.find { |d| d.mount_point == "/" }
          expect(root.min_size).to eq(Y2Storage::DiskSize.B(1))
          expect(root.max_size).to eq(Y2Storage::DiskSize.unlimited)
        end
      end
    end

    context "specifying filesystem options" do
      let(:partitioning_array) do
        [
          { "device" => "/dev/sda", "use" => "all",
           "partitions" => [root_spec, home_spec, swap_spec] }
        ]
      end

      let(:home_spec) do
        { "mount" => "/home", "filesystem" => "xfs", "mountby" => :uuid }
      end

      let(:swap_spec) do
        { "mount" => "swap" }
      end

      it "sets the filesystem" do
        devices = planner.planned_devices(drives_map)
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
          devices = planner.planned_devices(drives_map)
          srv = devices.find { |d| d.mount_point == "/srv" }
          expect(srv.filesystem_type).to eq(volspec.fs_type)
        end

        context "and no default is defined" do
          let(:volspec) { Y2Storage::VolumeSpecification.new({}) }

          it "sets filesystem to btrfs" do
            devices = planner.planned_devices(drives_map)
            srv = devices.find { |d| d.mount_point == "/srv" }
            expect(srv.filesystem_type).to eq(Y2Storage::Filesystems::Type::BTRFS)
          end

          context "and is a swap filesystem" do
            it "sets filesystem to swap" do
              devices = planner.planned_devices(drives_map)
              swap = devices.find { |d| d.mount_point == "swap" }
              expect(swap.filesystem_type).to eq(Y2Storage::Filesystems::Type::SWAP)
            end
          end
        end
      end

      it "sets the mountby properties" do
        devices = planner.planned_devices(drives_map)
        root = devices.find { |d| d.mount_point == "/" }
        home = devices.find { |d| d.mount_point == "/home" }
        expect(root.mount_by).to be_nil
        expect(home.mount_by).to eq(Y2Storage::Filesystems::MountByType::UUID)
      end

      it "sets fstab options" do
        devices = planner.planned_devices(drives_map)
        root = devices.find { |d| d.mount_point == "/" }
        expect(root.fstab_options).to eq(["ro", "acl"])
      end

      it "sets mkfs options" do
        devices = planner.planned_devices(drives_map)
        root = devices.find { |d| d.mount_point == "/" }
        expect(root.mkfs_options).to eq("-b 2048")
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

    context "using Btrfs for root" do
      let(:partitioning_array) do
        [{
          "device" => "/dev/sda", "use" => "all",
          "enable_snapshots" => snapshots, "partitions" => [root_spec, home_spec]
        }]
      end
      let(:home_spec) { { "mount" => "/home", "filesystem" => "btrfs" } }
      let(:root_spec) { { "mount" => "/", "filesystem" => "btrfs", "subvolumes" => subvolumes } }
      let(:snapshots) { false }

      let(:devices) { planner.planned_devices(drives_map) }
      let(:root) { devices.find { |d| d.mount_point == "/" } }
      let(:home) { devices.find { |d| d.mount_point == "/home" } }

      let(:subvolumes) { nil }
      let(:root_volume_spec) do
        Y2Storage::VolumeSpecification.new(
          "mount_point" => "/", "subvolumes" => subvolumes, "btrfs_default_subvolume" => "@"
        )
      end

      before do
        allow(Y2Storage::VolumeSpecification).to receive(:for).with("/")
          .and_return(root_volume_spec)
        allow(Y2Storage::VolumeSpecification).to receive(:for).with("/home")
          .and_return(nil)
      end

      context "when the profile contains a list of subvolumes" do
        let(:subvolumes) { ["var", { "path" => "srv", "copy_on_write" => false }, "home"] }

        it "plans a list of SubvolSpecification for root" do
          expect(root.subvolumes).to be_an Array
          expect(root.subvolumes).to all(be_a(Y2Storage::SubvolSpecification))
        end

        it "includes all the non-shadowed subvolumes" do
          expect(root.subvolumes).to contain_exactly(
            an_object_having_attributes(path: "var", copy_on_write: true),
            an_object_having_attributes(path: "srv", copy_on_write: false)
          )
        end

        # TODO: check that the user is warned, as soon as we introduce error
        # reporting
        it "excludes shadowed subvolumes" do
          expect(root.subvolumes.map(&:path)).to_not include "home"
        end
      end

      context "when there is no subvolumes list in the profile" do
        let(:subvolumes) { nil }
        let(:x86_subvolumes) { ["boot/grub2/i386-pc", "boot/grub2/x86_64-efi"] }
        let(:s390_subvolumes) { ["boot/grub2/s390x-emu"] }

        it "plans a list of SubvolSpecification for root" do
          expect(root.subvolumes).to be_an Array
          expect(root.subvolumes).to all(be_a(Y2Storage::SubvolSpecification))
        end

        it "plans the default subvolumes" do
          expect(root.subvolumes).to include(
            an_object_having_attributes(path: "srv",     copy_on_write: true),
            an_object_having_attributes(path: "tmp",     copy_on_write: true),
            an_object_having_attributes(path: "var/log", copy_on_write: true),
            an_object_having_attributes(path: "var/lib/libvirt/images", copy_on_write: false)
          )
        end

        it "excludes default subvolumes that are shadowed" do
          expect(root.subvolumes.map(&:path)).to_not include "home"
        end

        context "when architecture is x86" do
          let(:architecture) { :x86_64 }

          it "plans default x86 specific subvolumes" do
            expect(root.subvolumes.map(&:path)).to include(*x86_subvolumes)
          end
        end

        context "when architecture is s390" do
          let(:architecture) { :s390 }

          it "plans default s390 specific subvolumes" do
            expect(root.subvolumes.map(&:path)).to include(*s390_subvolumes)
          end
        end
      end

      context "when there is an empty subvolumes list in the profile" do
        let(:subvolumes) { [] }

        it "does not plan any subvolume" do
          expect(root.subvolumes).to eq([])
        end
      end

      context "when a subvolumes prefix is specified" do
        let(:root_spec) { { "mount" => "/", "filesystem" => "btrfs", "subvolumes_prefix" => "#" } }

        it "sets the default_subvolume name" do
          expect(root.default_subvolume).to eq("#")
        end
      end

      context "when subvolumes prefix is not specified" do
        let(:root_spec) { { "mount" => "/", "filesystem" => "btrfs" } }

        it "sets the default_subvolume to the default" do
          expect(root.default_subvolume).to eq("@")
        end

        context "and there is no default" do
          it "sets the default_subvolume to nil" do
            expect(home.default_subvolume).to be_nil
          end
        end
      end

      context "when the usage of snapshots is not specified" do
        let(:snapshots) { nil }

        it "enables snapshots for '/'" do
          expect(root.snapshots?).to eq true
        end

        it "does not enable snapshots for other filesystems in the drive" do
          expect(home.snapshots?).to eq false
        end
      end

      context "when snapshots are disabled" do
        let(:snapshots) { false }

        it "does not enable snapshots for '/'" do
          expect(root.snapshots?).to eq false
        end

        it "does not enable snapshots for other filesystems in the drive" do
          expect(home.snapshots?).to eq false
        end
      end

      context "when snapshots are enabled" do
        let(:snapshots) { true }

        it "enables snapshots for '/'" do
          expect(root.snapshots?).to eq true
        end

        it "does not enable snapshots for other filesystems in the drive" do
          expect(home.snapshots?).to eq false
        end
      end

      context "when root volume is supposed to be read-only" do
        let(:root_volume_spec) do
          Y2Storage::VolumeSpecification.new("mount_point" => "/", "btrfs_read_only" => true)
        end

        it "sets root partition as read-only" do
          expect(root.read_only).to eq(true)
        end
      end

      context "when subvolumes are disabled" do
        let(:root_spec) do
          { "mount" => "/", "filesystem" => "btrfs", "create_subvolumes" => false,
            "subvolumes" => subvolumes }
        end

        it "does not plan any subvolume" do
          expect(root.subvolumes).to eq([])
        end
      end
    end

    context "using LVM" do
      let(:partitioning_array) do
        [
          { "device" => "/dev/sda", "partitions" => [pv] }, vg
        ]
      end

      let(:vg) do
        { "device" => "/dev/#{lvm_group}", "partitions" => [root_spec], "type" => :CT_LVM }
      end

      let(:pv) do
        { "create" => true, "lvm_group" => lvm_group, "size" => "max", "type" => :CT_LVM }
      end

      let(:lvm_spec) do
        { "is_lvm_vg" => true, "partitions" => [root_spec] }
      end

      let(:root_spec) do
        {
          "mount" => "/", "filesystem" => "ext4", "lv_name" => "root", "size" => "20G",
          "label" => "rootfs", "stripes" => 2, "stripe_size" => 4
        }
      end

      it "returns volume group and logical volumes" do
        pv, vg = planner.planned_devices(drives_map)
        expect(pv).to be_a(Y2Storage::Planned::Partition)
        expect(vg).to be_a(Y2Storage::Planned::LvmVg)
        expect(vg).to have_attributes(
          "volume_group_name" => lvm_group,
          "reuse_name"        => nil
        )
        expect(vg.lvs).to contain_exactly(
          an_object_having_attributes(
            "logical_volume_name" => "root",
            "mount_point"         => "/",
            "reuse_name"          => nil,
            "min_size"            => 20.GiB,
            "max_size"            => 20.GiB,
            "label"               => "rootfs",
            "stripes"             => 2,
            "stripe_size"         => 4.KiB
          )
        )
      end

      context "specifying size" do
        using Y2Storage::Refinements::SizeCasts

        let(:root_spec) do
          { "mount" => "/", "filesystem" => "ext4", "lv_name" => "root", "size" => size }
        end

        context "when only a number is given" do
          let(:size) { "10" }

          it "sets the size according to that number and using unit B" do
            _pv, vg = planner.planned_devices(drives_map)
            root_lv = vg.lvs.first
            expect(root_lv.min_size).to eq(Y2Storage::DiskSize.B(10))
            expect(root_lv.max_size).to eq(Y2Storage::DiskSize.B(10))
          end
        end

        context "when a number+unit is given" do
          let(:size) { "5GB" }

          it "sets the size according to that number and using unit B" do
            _pv, vg = planner.planned_devices(drives_map)
            root_lv = vg.lvs.first
            expect(root_lv.min_size).to eq(5.GiB)
            expect(root_lv.max_size).to eq(5.GiB)
          end
        end

        context "when a percentage is given" do
          let(:size) { "50%" }

          it "sets the 'percent_size' value" do
            _pv, vg = planner.planned_devices(drives_map)
            root_lv = vg.lvs.first
            expect(root_lv).to have_attributes("percent_size" => 50)
          end
        end

        context "when 'max' is given" do
          let(:size) { "max" }

          it "sets the size according to that number and using unit B" do
            _pv, vg = planner.planned_devices(drives_map)
            root_lv = vg.lvs.first
            expect(root_lv.min_size).to eq(vg.extent_size)
            expect(root_lv.max_size).to eq(Y2Storage::DiskSize.unlimited)
          end

          it "sets the weight to '1'" do
            _pv, vg = planner.planned_devices(drives_map)
            root_lv = vg.lvs.first
            expect(root_lv.weight).to eq(1)
          end
        end

        context "when an invalid value is given" do
          let(:size) { "huh?" }

          it "skips the volume" do
            _pv, vg = planner.planned_devices(drives_map)
            expect(vg.lvs).to be_empty
          end

          it "registers an issue" do
            expect(issues_list).to be_empty
            planner.planned_devices(drives_map)
            issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::InvalidValue) }
            expect(issue.value).to eq("huh?")
            expect(issue.attr).to eq(:size)
            expect(issue.new_value).to eq(:skip)
          end
        end
      end

      context "reusing logical volumes" do
        let(:scenario) { "lvm-two-vgs" }

        context "when volume name is specified" do
          let(:root_spec) do
            {
              "create" => false, "mount" => "/", "filesystem" => "ext4", "lv_name" => "lv1",
              "size" => "20G"
            }
          end

          it "sets the reuse_name attribute of the volume group" do
            _pv, vg = planner.planned_devices(drives_map)
            expect(vg.reuse_name).to eq(lvm_group)
            expect(vg.make_space_policy).to eq(:remove)
          end

          it "sets the reuse_name attribute of logical volumes" do
            _pv, vg = planner.planned_devices(drives_map)
            expect(vg.reuse_name).to eq(lvm_group)
            expect(vg.lvs).to contain_exactly(
              an_object_having_attributes(
                "logical_volume_name" => "lv1",
                "reuse_name"          => "/dev/vg0/lv1"
              )
            )
          end
        end

        context "when label is specified" do
          let(:root_spec) do
            {
              "create" => false, "mount" => "/", "filesystem" => "ext4",
              "size" => "20G", "label" => "rootfs"
            }
          end

          it "sets the reuse_name attribute of logical volumes" do
            _pv, vg = planner.planned_devices(drives_map)
            expect(vg.reuse_name).to eq(lvm_group)
            expect(vg.lvs).to contain_exactly(
              an_object_having_attributes(
                "logical_volume_name" => "lv2",
                "reuse_name"          => "/dev/vg0/lv2"
              )
            )
          end
        end

        context "when the logical volume to be reused does not exist" do
          let(:root_spec) do
            {
              "create" => false, "mount" => "/", "filesystem" => "ext4", "lv_name" => "new_lv",
              "size" => "20G"
            }
          end

          it "adds a new logical volume" do
            _pv, vg = planner.planned_devices(drives_map)
            expect(vg.reuse_name).to be_nil
            expect(vg.lvs).to contain_exactly(
              an_object_having_attributes(
                "logical_volume_name" => "new_lv",
                "reuse_name"          => nil
              )
            )
          end

          it "registers an issue" do
            expect(issues_list).to be_empty
            planner.planned_devices(drives_map)
            issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingReusableDevice) }
            expect(issue).to_not be_nil
          end
        end

        context "when no volume name or label is specified" do
          let(:root_spec) do
            {
              "create" => false, "mount" => "/", "filesystem" => "ext4", "size" => "20G"
            }
          end

          it "adds a new logical volume" do
            _pv, vg = planner.planned_devices(drives_map)
            expect(vg.reuse_name).to be_nil
            expect(vg.lvs).to contain_exactly(
              an_object_having_attributes(
                "reuse_name" => nil
              )
            )
          end

          it "registers an issue" do
            expect(issues_list).to be_empty
            planner.planned_devices(drives_map)
            issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingReuseInfo) }
            expect(issue).to_not be_nil
          end

          it "does not register a missing reusable device error" do
            expect(issues_list).to be_empty
            planner.planned_devices(drives_map)
            issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingReusableDevice) }
            expect(issue).to be_nil
          end
        end

        context "when the volume group does not exist" do
          let(:vg) do
            { "device" => "/dev/dummy", "partitions" => [root_spec], "type" => :CT_LVM }
          end

          let(:root_spec) do
            {
              "create" => false, "mount" => "/", "filesystem" => "ext4", "lv_name" => "lv1",
              "size" => "20G"
            }
          end

          it "registers an issue" do
            expect(issues_list).to be_empty
            planner.planned_devices(drives_map)
            issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingReusableDevice) }
            expect(issue).to_not be_nil
          end
        end
      end

      context "when unknown logical volumes are required to be kept" do
        let(:scenario) { "lvm-two-vgs" }

        let(:vg) do
          {
            "device" => "/dev/#{lvm_group}", "partitions" => [root_spec], "type" => :CT_LVM,
            "keep_unknown_lv" => true
          }
        end

        it "sets the reuse_name attribute of the volume group" do
          _pv, vg = planner.planned_devices(drives_map)
          expect(vg).to have_attributes(
            "volume_group_name" => lvm_group,
            "reuse_name"        => lvm_group,
            "make_space_policy" => :keep
          )
        end

        context "but volume group does not exist" do
          let(:vg) do
            {
              "device" => "/dev/dummy", "partitions" => [root_spec], "type" => :CT_LVM,
              "keep_unknown_lv" => true
            }
          end

          it "adds a new volume group" do
            _pv, vg = planner.planned_devices(drives_map)
            expect(vg).to have_attributes(
              "volume_group_name" => "dummy",
              "reuse_name"        => nil,
              "make_space_policy" => :keep
            )
          end

          it "registers an issue" do
            expect(issues_list).to be_empty
            planner.planned_devices(drives_map)
            issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingReusableDevice) }
            expect(issue).to_not be_nil
          end
        end
      end

      context "when trying to reuse a logical volume which is in another volume group" do
        let(:lvm_group) { "vg1" }
        let(:scenario) { "lvm-two-vgs" }

        let(:root_spec) do
          {
            "create" => false, "mount" => "/", "filesystem" => "ext4", "lv_name" => "lv2",
            "size" => "20G", "label" => "rootfs"
          }
        end

        it "does not set the reuse_name attribute of the logical volume" do
          _pv, vg = planner.planned_devices(drives_map)
          expect(vg.lvs).to contain_exactly(
            an_object_having_attributes(
              "logical_volume_name" => "lv2",
              "reuse_name"          => nil
            )
          )
        end
      end

      context "using a thin pool" do
        let(:vg) do
          {
            "device" => "/dev/#{lvm_group}", "partitions" => [root_spec, home_spec, pool_spec],
            "type" => :CT_LVM, "keep_unknown_lv" => true
          }
        end

        let(:pool_spec) do
          { "create" => true, "pool" => true, "lv_name" => "pool0", "size" => "20G" }
        end

        let(:root_spec) do
          {
            "create" => true, "mount" => "/", "filesystem" => "ext4", "lv_name" => "root",
            "size" => "10G", "used_pool" => "pool0"
          }
        end

        let(:home_spec) do
          {
            "create" => true, "mount" => "/home", "filesystem" => "ext4", "lv_name" => "home",
            "size" => "10G", "used_pool" => "pool0"
          }
        end

        it "sets lv_type and thin pool name" do
          _pv, vg = planner.planned_devices(drives_map)
          pool = vg.lvs.find { |v| v.logical_volume_name == "pool0" }

          expect(pool.lv_type).to eq(Y2Storage::LvType::THIN_POOL)
          expect(pool.thin_lvs).to include(
            an_object_having_attributes(
              "logical_volume_name" => "root",
              "lv_type"             => Y2Storage::LvType::THIN
            ),
            an_object_having_attributes(
              "logical_volume_name" => "home",
              "lv_type"             => Y2Storage::LvType::THIN
            )
          )
        end

        context "when the thin pool is not defined" do
          let(:pool_spec) do
            { "create" => true, "pool" => true, "lv_name" => "pool1", "size" => "20G" }
          end

          it "registers an issue" do
            planner.planned_devices(drives_map)
            issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::ThinPoolNotFound) }
            expect(issue).to_not be_nil
          end
        end
      end
    end
  end
end
