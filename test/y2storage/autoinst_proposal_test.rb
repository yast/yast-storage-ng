#!/usr/bin/env rspec
# encoding: utf-8
#
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

require_relative "spec_helper"
require "storage"
require "y2storage"

describe Y2Storage::AutoinstProposal do
  using Y2Storage::Refinements::SizeCasts

  subject(:proposal) do
    described_class.new(
      partitioning: partitioning, devicegraph: fake_devicegraph, issues_list: issues_list
    )
  end

  let(:partitioning) { [] }
  let(:issues_list) { Y2Storage::AutoinstIssues::List.new }
  let(:vg_name) { "system" }

  before do
    allow(Yast::Mode).to receive(:auto).and_return(true)
  end

  describe "#propose" do
    using Y2Storage::Refinements::SizeCasts

    ROOT_PART = { "filesystem" => :ext4, "mount" => "/", "size" => "25%", "label" => "new_root" }.freeze

    let(:scenario) { "windows-linux-free-pc" }

    # include_context "proposal"
    let(:root) { ROOT_PART.merge("create" => true) }

    let(:home) do
      { "filesystem" => :xfs, "mount" => "/home", "size" => "50%", "create" => true }
    end

    let(:swap) do
      { "filesystem" => :swap, "mount" => "swap", "size" => "1GB", "create" => true }
    end

    let(:partitioning) do
      [{ "device" => "/dev/sda", "use" => "all", "partitions" => [root, home] }]
    end

    before do
      fake_scenario(scenario)
    end

    context "when partitions are specified" do
      it "proposes a layout including specified partitions" do
        proposal.propose
        devicegraph = proposal.devices

        expect(devicegraph.partitions.size).to eq(2)
        root, home = devicegraph.partitions

        expect(root).to have_attributes(
          filesystem_type:       Y2Storage::Filesystems::Type::EXT4,
          filesystem_mountpoint: "/",
          size:                  125.GiB
        )

        expect(home).to have_attributes(
          filesystem_type:       Y2Storage::Filesystems::Type::XFS,
          filesystem_mountpoint: "/home",
          size:                  250.GiB
        )
      end

      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end

      context "when using btrfs" do
        let(:root) { ROOT_PART.merge("create" => true, "filesystem" => :btrfs) }
        let(:root_fs) { proposal.devices.partitions.first.filesystem }

        it "creates Btrfs subvolumes" do
          proposal.propose
          expect(root_fs.btrfs_subvolumes).to_not be_empty
          expect(root_fs.btrfs_subvolumes).to all(be_a(Y2Storage::BtrfsSubvolume))
        end

        it "enables Snapper configuration for '/' by default" do
          proposal.propose
          expect(root_fs.configure_snapper).to eq true
        end

        context "when disabling snapshots" do
          let(:partitioning) do
            [{
              "device" => "/dev/sda", "use" => "all", "partitions" => [root], "enable_snapshots" => false
            }]
          end

          it "does not enable Snapper configuration for '/'" do
            proposal.propose
            expect(root_fs.configure_snapper).to eq false
          end
        end

        context "when subvolumes prefix is set for a given partition" do
          let(:root) do
            ROOT_PART.merge(
              "create" => true, "filesystem" => :btrfs, "subvolumes_prefix" => "PREFIX"
            )
          end

          it "sets the subvolumes prefix" do
            proposal.propose
            expect(root_fs.subvolumes_prefix).to eq("PREFIX")
          end
        end
      end

      context "when no root is proposed" do
        let(:partitioning) do
          [{ "device" => "/dev/sda", "use" => "all", "partitions" => [home] }]
        end

        it "registers an issue" do
          proposal.propose
          issue = issues_list.find do |i|
            i.is_a?(Y2Storage::AutoinstIssues::MissingRoot)
          end
          expect(issue).to_not be_nil
        end
      end
    end

    describe "reusing partitions" do
      let(:partitioning) do
        [{ "device" => "/dev/sda", "use" => "free", "partitions" => [root] }]
      end

      context "when boot partition does not fit" do
        let(:scenario) { "windows-pc-gpt" }

        let(:root) do
          { "mount" => "/", "partition_nr" => 1, "create" => false }
        end

        it "does not create the boot partition" do
          proposal.propose
          devicegraph = proposal.devices
          expect(devicegraph.partitions.size).to eq(2)
        end

        it "registers an issue" do
          expect(proposal.issues_list).to be_empty
          proposal.propose
          issue = proposal.issues_list.find do |i|
            i.is_a?(Y2Storage::AutoinstIssues::CouldNotCreateBoot)
          end
          expect(issue).to_not be_nil
        end
      end

      context "when an existing partition_nr is specified" do
        let(:root) do
          { "mount" => "/", "partition_nr" => 3, "create" => false }
        end

        it "reuses the partition with the given partition number" do
          proposal.propose
          devicegraph = proposal.devices
          reused_part = devicegraph.partitions.find { |p| p.name == "/dev/sda3" }
          expect(reused_part).to have_attributes(
            filesystem_type:       Y2Storage::Filesystems::Type::EXT4,
            filesystem_mountpoint: "/"
          )
        end
      end

      context "when an existing label is specified" do
        let(:root) do
          { "mount" => "/", "mountby" => :label, "label" => "root",
            "create" => false }
        end

        it "reuses the partition with the given label" do
          proposal.propose
          devicegraph = proposal.devices
          reused_part = devicegraph.partitions.find { |p| p.filesystem_label == "root" }
          expect(reused_part).to have_attributes(
            filesystem_type:       Y2Storage::Filesystems::Type::EXT4,
            filesystem_mountpoint: "/"
          )
        end
      end

      context "when partition is marked to be formatted" do
        let(:root) do
          { "mount" => "/", "partition_nr" => 3, "create" => false,
            "format" => true, "filesystem" => :btrfs }
        end

        it "reuses the partition with the given format" do
          proposal.propose
          devicegraph = proposal.devices
          reused_part = devicegraph.partitions.find { |p| p.name == "/dev/sda3" }
          expect(reused_part).to have_attributes(
            filesystem_type:       Y2Storage::Filesystems::Type::BTRFS,
            filesystem_mountpoint: "/"
          )
        end
      end

      context "when a different filesystem is specified" do
        let(:root) do
          { "mount" => "/", "partition_nr" => 3, "create" => false,
            "format" => false, "filesystem" => :btrfs }
        end

        it "ignores the given filesystem" do
          proposal.propose
          devicegraph = proposal.devices
          reused_part = devicegraph.partitions.find { |p| p.name == "/dev/sda3" }
          expect(reused_part).to have_attributes(
            filesystem_type:       Y2Storage::Filesystems::Type::EXT4,
            filesystem_mountpoint: "/"
          )
        end
      end

      context "when the reused partition is in a DASD" do
        let(:scenario) { "dasd_50GiB" }

        let(:root) do
          { "mount" => "/", "partition_nr" => 1, "create" => false }
        end

        # Regression test for bug#1098594:
        # the partitions are on an Dasd (not a Disk), so when the code did
        #   partition.disk
        # it returned nil and produced an exception afterwards
        it "does not crash" do
          expect { proposal.propose }.to_not raise_error
        end

        it "reuses the partition with the given partition number" do
          proposal.propose
          reused_part = proposal.devices.partitions.find { |p| p.name == "/dev/sda1" }
          expect(reused_part).to have_attributes(
            filesystem_type:       Y2Storage::Filesystems::Type::EXT2,
            filesystem_mountpoint: "/"
          )
        end
      end
    end

    describe "resizing partitions" do
      let(:root) do
        {
          "mount" => "/", "partition_nr" => 3, "create" => false, "resize" => true,
          "size" => size
        }
      end

      let(:size) { "100GiB" }
      let(:resize_ok) { true }
      let(:resize_info) do
        instance_double(
          Y2Storage::ResizeInfo, min_size: 512.MiB, max_size: 245.GiB, resize_ok?: resize_ok,
            reasons: 0, reason_texts: []
        )
      end

      before do
        allow_any_instance_of(Y2Storage::Partition).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      it "sets the partitions' size" do
        proposal.propose
        devicegraph = proposal.devices
        reused_part = devicegraph.partitions.find { |p| p.name == "/dev/sda3" }
        expect(reused_part.size).to eq(100.GiB)
      end

      context "when requested size is smaller than the minimal resize limit" do
        let(:size) { "256MB" }

        it "sets the size to the minimal allowed size" do
          proposal.propose
          devicegraph = proposal.devices
          reused_part = devicegraph.partitions.find { |p| p.name == "/dev/sda3" }
          expect(reused_part.size).to eq(resize_info.min_size)
        end
      end

      context "when requested size is greater than the maximal resize limit" do
        let(:size) { "250GiB" }

        it "sets the size to the maximal allowed size" do
          proposal.propose
          devicegraph = proposal.devices
          reused_part = devicegraph.partitions.find { |p| p.name == "/dev/sda3" }
          expect(reused_part.size).to eq(resize_info.max_size)
        end
      end
    end

    describe "removing partitions" do
      let(:scenario) { "windows-linux-free-pc" }
      let(:partitioning) { [{ "device" => "/dev/sda", "partitions" => [root], "use" => use }] }

      context "when the whole disk should be used" do
        let(:use) { "all" }

        it "removes the old partitions" do
          proposal.propose
          devicegraph = proposal.devices
          expect(devicegraph.partitions.size).to eq(1)
          part = devicegraph.partitions.first
          expect(part).to have_attributes(filesystem_label: "new_root")
        end
      end

      context "when only free space should be used" do
        let(:use) { "free" }

        it "keeps the old partitions" do
          proposal.propose
          devicegraph = proposal.devices
          labels = devicegraph.partitions.map(&:filesystem_label)
          expect(labels).to eq(["windows", "swap", "root", "new_root"])
        end

        it "raises an error if there is not enough space"
      end

      context "when only space from Linux partitions should be used" do
        let(:use) { "linux" }

        it "keeps all partitions except Linux ones" do
          proposal.propose
          devicegraph = proposal.devices
          labels = devicegraph.partitions.map(&:filesystem_label)
          expect(labels).to eq(["windows", "new_root"])
        end
      end

      context "when the device should be initialized" do
        let(:partitioning) { [{ "device" => "/dev/sda", "partitions" => [root], "initialize" => true }] }
        let(:boot_checker) { double("Y2Storage::BootRequirementsChecker", needed_partitions: []) }
        before { allow(Y2Storage::BootRequirementsChecker).to receive(:new).and_return boot_checker }

        it "removes the old partitions" do
          proposal.propose
          devicegraph = proposal.devices
          expect(devicegraph.partitions.size).to eq(1)
          part = devicegraph.partitions.first
          expect(part).to have_attributes(filesystem_label: "new_root")
        end
      end
    end

    describe "reusing logical volumes" do
      let(:scenario) { "lvm-two-vgs" }

      let(:lvm_group) { "vg0" }

      let(:root) do
        {
          "create" => false, "mount" => "/", "filesystem" => "ext4", "lv_name" => "lv1",
          "size" => "20G"
        }
      end

      let(:partitioning) do
        [
          { "device" => "/dev/sda", "use" => "all", "partitions" => [pv] }, vg
        ]
      end

      let(:vg) do
        { "device" => "/dev/#{lvm_group}", "partitions" => [root], "type" => :CT_LVM }
      end

      let(:pv) do
        { "create" => false, "lvm_group" => lvm_group, "size" => "max", "type" => :CT_LVM }
      end

      it "reuses the volume group" do
        proposal.propose
        devicegraph = proposal.devices
        expect(devicegraph.partitions).to contain_exactly(
          an_object_having_attributes("name" => "/dev/sda1"), # new pv
          an_object_having_attributes("name" => "/dev/sda3"),
          an_object_having_attributes("name" => "/dev/sda5")
        )

        vg = devicegraph.lvm_vgs.first
        expect(vg.vg_name).to eq(lvm_group)
        expect(vg.lvm_pvs.map(&:blk_device)).to contain_exactly(
          an_object_having_attributes("name" => "/dev/sda1"), # new pv
          an_object_having_attributes("name" => "/dev/sda5")
        )
      end
    end

    describe "resizing logical volumes" do
      let(:scenario) { "lvm-two-vgs" }

      let(:lvm_group) { "vg0" }

      let(:root) do
        {
          "create" => false, "mount" => "/", "filesystem" => "ext4", "lv_name" => "lv1",
          "size" => size, "resize" => true
        }
      end

      let(:partitioning) do
        [
          { "device" => "/dev/sda", "use" => "all", "partitions" => [pv] }, vg
        ]
      end

      let(:vg) do
        { "device" => "/dev/#{lvm_group}", "partitions" => [root], "type" => :CT_LVM }
      end

      let(:pv) do
        { "create" => false, "lvm_group" => lvm_group, "size" => "max", "type" => :CT_LVM }
      end

      let(:size) { "1GiB" }

      let(:resize_info) do
        instance_double(
          Y2Storage::ResizeInfo, min_size: 512.MiB, max_size: 2.GiB, resize_ok?: true,
            reasons: 0, reason_texts: []
        )
      end

      before do
        allow_any_instance_of(Y2Storage::LvmLv).to receive(:detect_resize_info)
          .and_return(resize_info)
      end

      it "sets the partitions' size" do
        proposal.propose
        devicegraph = proposal.devices
        reused_lv = devicegraph.lvm_lvs.find { |l| l.name == "/dev/vg0/lv1" }
        expect(reused_lv.size).to eq(1.GiB)
      end

      context "when requested size smaller than the minimal resize limit" do
        let(:size) { "0.5GiB" }

        it "sets the size to the minimal allowed size" do
          proposal.propose
          devicegraph = proposal.devices
          reused_lv = devicegraph.lvm_lvs.find { |l| l.name == "/dev/vg0/lv1" }
          expect(reused_lv.size).to eq(resize_info.min_size)
        end
      end

      context "when requested size greater than the maximal resize limit" do
        let(:size) { "4GiB" }

        it "sets the size to the maximal allowed size" do
          proposal.propose
          devicegraph = proposal.devices
          reused_lv = devicegraph.lvm_lvs.find { |l| l.name == "/dev/vg0/lv1" }
          expect(reused_lv.size).to eq(resize_info.max_size)
        end
      end
    end

    describe "skipping a disk" do
      let(:skip_list) do
        [{ "skip_key" => "name", "skip_value" => skip_device }]
      end

      let(:partitioning) do
        [{ "use" => "all", "partitions" => [root, home], "skip_list" => skip_list }]
      end

      context "when a disk is included in the skip_list" do
        let(:skip_device) { "sda" }

        it "skips the given disk" do
          proposal.propose
          devicegraph = proposal.devices
          sdb1 = devicegraph.partitions.find { |p| p.name == "/dev/sdb1" }
          expect(sdb1).to have_attributes(filesystem_label: "new_root")
          sda1 = devicegraph.partitions.first
          expect(sda1).to have_attributes(filesystem_label: "windows")
        end
      end

      context "when no disk is included in the skip_list" do
        let(:skip_device) { "sdc" }

        it "does not skip any disk" do
          proposal.propose
          devicegraph = proposal.devices
          sda1 = devicegraph.partitions.first
          expect(sda1).to have_attributes(filesystem_label: "new_root")
        end
      end

      context "when no disks are suitable for installation" do
        let(:skip_list) do
          [{ "skip_key" => "name", "skip_value" => "sda" },
           { "skip_key" => "name", "skip_value" => "sdb" }]
        end

        it "registers an issue" do
          expect(proposal.issues_list).to be_empty
          proposal.propose
          issue = proposal.issues_list.find do |i|
            i.is_a?(Y2Storage::AutoinstIssues::NoDisk)
          end
          expect(issue).to_not be_nil
        end
      end
    end

    describe "automatic partitioning" do
      let(:partitioning) do
        [{ "device" => "/dev/sda", "use" => use }]
      end

      let(:settings) do
        Y2Storage::ProposalSettings.new_for_current_product.tap do |settings|
          settings.use_lvm = false
          settings.use_separate_home = true
        end
      end

      let(:planned_root) do
        planned_partition(
          mount_point: "/",
          type:        :ext4,
          size:        5.GiB,
          min_size:    5.GiB
        )
      end

      let(:planner) do
        instance_double(Y2Storage::Proposal::DevicesPlanner, planned_devices: [planned_root])
      end

      let(:use) { "all" }

      before do
        allow(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
          .and_return(settings)
        allow(Y2Storage::Proposal::DevicesPlanner).to receive(:new)
          .with(settings, Y2Storage::Devicegraph)
          .and_return(planner)
      end

      it "falls back to the product's proposal with given disks" do
        proposal.propose
        devicegraph = proposal.devices
        sda = devicegraph.disks.find { |d| d.name == "/dev/sda" }
        expect(sda.partitions).to contain_exactly(
          an_object_having_attributes("filesystem_mountpoint" => "/")
        )
      end

      context "when a subset of partitions should be used" do
        let(:use) { "1" }

        it "keeps partitions that should not be removed" do
          proposal.propose
          devicegraph = proposal.devices
          sda = devicegraph.disks.find { |d| d.name == "/dev/sda" }
          expect(sda.partitions.size).to eq(3)
        end
      end

      context "when snapshots are disabled in the profile" do
        let(:partitioning) do
          [{ "device" => "/dev/sda", "use" => use, "enable_snapshots" => false }]
        end

        it "disables use_snapshots setting" do
          expect(settings).to receive(:use_snapshots=).with(false)
          proposal.propose
        end
      end

      context "when snapshots are enabled in the profile" do
        let(:partitioning) do
          [{ "device" => "/dev/sda", "use" => use, "enable_snapshots" => true }]
        end

        it "enables use_snapshots setting" do
          expect(settings).to receive(:use_snapshots=).with(true)
          proposal.propose
        end
      end
    end

    describe "with Xen virtual partitions" do
      let(:xvda1_sect) do
        {
          "partition_nr" => 1, "create" => false,
          "filesystem" => "btrfs", "format" => true, "mount" => "/"
        }
      end

      let(:xvda2_sect) do
        {
          "partition_nr" => 2, "create" => false, "mount_by" => "device",
          "filesystem" => "swap", "format" => true, "mount" => "swap"
        }
      end

      let(:xvdc1_sect) do
        { "filesystem" => :xfs, "mount" => "/home", "size" => "max", "create" => true }
      end

      context "and no other kind of devices" do
        let(:scenario) { "xen-partitions.xml" }

        let(:partitioning) do
          [{ "device" => "/dev/xvda", "use" => "all", "partitions" => [xvda1_sect, xvda2_sect] }]
        end

        it "does not register any issue" do
          proposal.propose
          expect(issues_list).to be_empty
        end

        it "correctly formats all the virtual partitions" do
          proposal.propose

          xvda1 = proposal.devices.find_by_name("/dev/xvda1")
          expect(xvda1.filesystem).to have_attributes(
            type:       Y2Storage::Filesystems::Type::BTRFS,
            mount_path: "/"
          )
          xvda2 = proposal.devices.find_by_name("/dev/xvda2")
          expect(xvda2.filesystem).to have_attributes(
            type:       Y2Storage::Filesystems::Type::SWAP,
            mount_path: "swap"
          )
        end
      end

      context "and Xen hard disks" do
        let(:scenario) { "xen-disks-and-partitions.xml" }

        let(:partitioning) do
          [
            { "device" => "/dev/xvda", "use" => "all", "partitions" => [xvda1_sect, xvda2_sect] },
            { "device" => "/dev/xvdc", "use" => "all", "partitions" => [xvdc1_sect] }
          ]
        end

        it "correctly formats all the virtual and real partitions" do
          proposal.propose

          xvda1 = proposal.devices.find_by_name("/dev/xvda1")
          expect(xvda1.filesystem).to have_attributes(
            type:       Y2Storage::Filesystems::Type::BTRFS,
            mount_path: "/"
          )
          xvda2 = proposal.devices.find_by_name("/dev/xvda2")
          expect(xvda2.filesystem).to have_attributes(
            type:       Y2Storage::Filesystems::Type::SWAP,
            mount_path: "swap"
          )

          # NOTE: /dev/xvdc1 is not the only /dev/xvdc partition in the final
          # system. AutoYaST also creates a bios_boot partition because it
          # always adds partitions needed for booting. In a Xen environment
          # with Xen virtual partitions that behavior is probably undesired
          # (let's wait for feedback about it).
          xvdc = proposal.devices.find_by_name("/dev/xvdc")
          expect(xvdc.partitions).to include(
            an_object_having_attributes(
              filesystem_type:       Y2Storage::Filesystems::Type::XFS,
              filesystem_mountpoint: "/home"
            )
          )
        end
      end
    end

    describe "LVM" do
      let(:partitioning) do
        [
          { "device" => "/dev/sda", "use" => "all", "partitions" => [lvm_pv] },
          { "device" => "/dev/#{vg_name}", "partitions" => lvs, "type" => :CT_LVM }
        ]
      end

      let(:lvm_pv) do
        { "create" => true, "lvm_group" => vg_name, "size" => "max" }
      end

      let(:root_spec) do
        { "mount" => "/", "filesystem" => "ext4", "lv_name" => "root", "size" => "1GB" }
      end

      let(:lvs) { [root_spec] }

      it "creates requested volume groups" do
        proposal.propose
        devicegraph = proposal.devices
        expect(devicegraph.lvm_vgs).to contain_exactly(
          an_object_having_attributes(
            "vg_name" => vg_name
          )
        )
      end

      it "creates requested logical volumes" do
        proposal.propose
        devicegraph = proposal.devices
        expect(devicegraph.lvm_lvs).to contain_exactly(
          an_object_having_attributes(
            "lv_name" => "root",
            "size"    => 1.GiB
          )
        )
      end

      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end

      context "when 'max' is used as size" do
        let(:root_spec) do
          { "mount" => "/", "filesystem" => "ext4", "lv_name" => "root", "size" => "max" }
        end

        it "uses the whole volume group" do
          proposal.propose
          devicegraph = proposal.devices
          lv = devicegraph.lvm_lvs.first
          expect(lv.size).to eq(500.GiB - 4.MiB)
        end
      end

      context "when using btrfs" do
        let(:root_spec) do
          { "mount" => "/", "filesystem" => "btrfs", "lv_name" => "root", "size" => "1G" }
        end
        let(:root_fs) do
          Y2Storage::LvmLv.find_by_name(proposal.devices, "/dev/#{vg_name}/root").filesystem
        end

        it "creates Btrfs subvolumes" do
          proposal.propose
          expect(root_fs.btrfs_subvolumes).to_not be_empty
          expect(root_fs.btrfs_subvolumes).to all(be_a(Y2Storage::BtrfsSubvolume))
        end

        it "enables Snapper configuration for '/' by default" do
          proposal.propose
          expect(root_fs.configure_snapper).to eq true
        end

        context "when disabling snapshots in the drive containing '/'" do
          let(:partitioning) do
            [
              { "device" => "/dev/sda", "use" => "all", "partitions" => [lvm_pv] },
              {
                "device" => "/dev/#{vg_name}", "partitions" => [root_spec],
                "type" => :CT_LVM, "enable_snapshots" => false
              }
            ]
          end

          it "does not enable Snapper configuration for '/'" do
            proposal.propose
            expect(root_fs.configure_snapper).to eq false
          end
        end

        context "when disabling snapshots in any other drive" do
          let(:partitioning) do
            [
              {
                "device" => "/dev/sda", "use" => "all",
                "partitions" => [lvm_pv], "enable_snapshots" => false
              },
              { "device" => "/dev/#{vg_name}", "partitions" => [root_spec], "type" => :CT_LVM }
            ]
          end

          it "enables Snapper configuration for '/'" do
            proposal.propose
            expect(root_fs.configure_snapper).to eq true
          end
        end
      end

      context "when no root is proposed" do
        let(:home_spec) do
          { "mount" => "/home", "filesystem" => "ext4", "lv_name" => "root", "size" => "1G" }
        end

        let(:lvs) { [home_spec] }

        it "registers an issue" do
          proposal.propose
          issue = issues_list.find do |i|
            i.is_a?(Y2Storage::AutoinstIssues::MissingRoot)
          end
          expect(issue).to_not be_nil
        end
      end

      context "when there is not enough space" do
        let(:root_spec) do
          { "mount" => "/", "filesystem" => "btrfs", "lv_name" => "root", "size" => "300GiB" }
        end

        let(:home_spec) do
          { "mount" => "/home", "filesystem" => "ext4", "lv_name" => "home", "size" => "300GiB" }
        end

        let(:lvs) { [root_spec, home_spec] }

        it "reduces logical volumes proportionally" do
          proposal.propose
          devicegraph = proposal.devices
          expect(devicegraph.lvm_lvs).to contain_exactly(
            an_object_having_attributes("lv_name" => "root", "size" => 250.GiB),
            an_object_having_attributes("lv_name" => "home", "size" => 250.GiB - 4.MiB)
          )
        end

        it "adds an issue for each reduced logical volume" do
          proposal.propose
          issues = issues_list.select do |i|
            i.is_a?(Y2Storage::AutoinstIssues::ShrinkedPlannedDevices)
          end
          expect(issues.size).to eq(1)
        end
      end

      context "when using a thin pool" do
        let(:root_spec) do
          {
            "mount" => "/", "filesystem" => "btrfs", "lv_name" => "root", "size" => "100GB",
            "used_pool" => "pool0"
          }
        end

        let(:pool_spec) do
          { "lv_name" => "pool0", "size" => "500GiB", "pool" => true }
        end

        let(:lvs) { [pool_spec, root_spec] }

        it "creates thin pool and thin volumes" do
          proposal.propose
          devicegraph = proposal.devices
          expect(devicegraph.lvm_lvs).to contain_exactly(
            an_object_having_attributes("lv_name" => "root"),
            an_object_having_attributes("lv_name" => "pool0")
          )
          pool = devicegraph.lvm_lvs.find { |v| v.lv_name == "pool0" }
          # around 260MiB are used for metadata
          expect(pool.size).to eq(500.GiB - 260.MiB)
        end

        it "does not register an issue about missing root partition" do
          proposal.propose
          issue = issues_list.find do |i|
            i.is_a?(Y2Storage::AutoinstIssues::MissingRoot)
          end
          expect(issue).to be_nil
        end
      end

      context "when reusing a thin pool" do
        let(:scenario) { "trivial_lvm" }
        let(:vg_name) { "vg0" }
        let(:existing_pool_name) { "pool0" }

        let(:lvm_pv) do
          { "create" => false, "partition_nr" => 1, "lvm_group" => vg_name, "size" => "max" }
        end

        let(:root_spec) do
          {
            "mount" => "/", "filesystem" => "btrfs", "lv_name" => "root", "size" => "150GB",
            "create" => false, "used_pool" => "pool0", "format" => false
          }
        end

        let(:lvs) { [pool_spec, root_spec] }

        let(:vg) { fake_devicegraph.lvm_vgs.first }

        before do
          # FIXME: add support to the fake factory for LVM thin pools
          vg.remove_descendants
          thin_pool_lv = vg.create_lvm_lv(existing_pool_name, Y2Storage::LvType::THIN_POOL, 200.GiB)
          thin_lv = thin_pool_lv.create_lvm_lv("root", Y2Storage::LvType::THIN, 150.GiB)
          thin_lv.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
        end

        context "and the thin pool is marked to be reused" do
          let(:pool_spec) do
            { "lv_name" => "pool0", "size" => "200GiB", "pool" => true, "create" => false }
          end

          it "reuses thin pool and thin volumes" do
            proposal.propose
            devicegraph = proposal.devices
            pool = devicegraph.lvm_lvs.find { |v| v.lv_name == "pool0" }
            root_lv = pool.lvm_lvs.first
            # keep the same filesystem type
            expect(root_lv.filesystem_type).to eq(Y2Storage::Filesystems::Type::EXT4)
          end
        end

        context "and the thin pool is not marked to be reused" do
          let(:pool_spec) do
            { "lv_name" => "pool0", "size" => "200GiB", "pool" => true }
          end

          it "reuses thin pool and thin volumes" do
            proposal.propose
            devicegraph = proposal.devices
            pool = devicegraph.lvm_lvs.find { |v| v.lv_name == "pool0" }
            root_lv = pool.lvm_lvs.first
            expect(root_lv.filesystem_type).to eq(Y2Storage::Filesystems::Type::EXT4)
          end
        end

        context "and the thin pool does not exist" do
          let(:existing_pool_name) { "pool1" }

          let(:pool_spec) do
            { "lv_name" => "pool0", "size" => "200GiB", "pool" => true }
          end

          it "creates a new thin logical volume" do
            proposal.propose
            devicegraph = proposal.devices
            pool = devicegraph.lvm_lvs.find { |v| v.lv_name == "pool0" }
            root_lv = pool.lvm_lvs.first
            expect(root_lv.filesystem_type).to eq(Y2Storage::Filesystems::Type::BTRFS)
          end

          it "registers an issue" do
            proposal.propose
            issue = issues_list.find do |i|
              i.is_a?(Y2Storage::AutoinstIssues::ThinPoolNotFound)
            end
            expect(issue).to_not be_nil
          end
        end
      end
    end

    describe "RAID" do
      let(:partitioning) do
        [
          { "device" => "/dev/sda", "use" => "all", "partitions" => [root_spec, raid_spec] },
          { "device" => "/dev/sdb", "use" => "all", "partitions" => [raid_spec] },
          { "device" => "/dev/md", "partitions" => [home_spec] }
        ]
      end

      let(:md_device) { "/dev/md1" }

      let(:home_spec) do
        {
          "mount" => "/home", "filesystem" => "xfs", "size" => "max",
          "raid_name" => md_device, "partition_nr" => 1, "raid_options" => raid_options
        }
      end

      let(:raid_options) do
        { "raid_type" => "raid1" }
      end

      let(:root_spec) do
        { "mount" => "/", "filesystem" => "ext4", "size" => "5G" }
      end

      let(:raid_spec) do
        { "raid_name" => md_device, "size" => "20GB", "partition_id" => 253 }
      end

      it "creates a RAID" do
        proposal.propose
        devicegraph = proposal.devices
        expect(devicegraph.md_raids).to contain_exactly(
          an_object_having_attributes(
            "number" => 1
          )
        )
      end

      it "adds the specified devices" do
        proposal.propose
        devicegraph = proposal.devices
        raid = devicegraph.md_raids.first
        expect(raid.devices.map(&:name)).to contain_exactly("/dev/sda2", "/dev/sdb1")
      end

      context "when using a named RAID" do
        let(:raid_options) { { "raid_name" => md_device, "raid_type" => "raid0" } }
        let(:md_device) { "/dev/md/data" }

        it "uses the name instead of a number" do
          proposal.propose
          devicegraph = proposal.devices
          expect(devicegraph.md_raids).to contain_exactly(
            an_object_having_attributes(
              "name"     => "/dev/md/data",
              "md_level" => Y2Storage::MdLevel::RAID0
            )
          )
        end
      end

      context "reusing a RAID" do
        let(:scenario) { "md_raid.xml" }
        let(:md_device) { "/dev/md/md0" }

        let(:partitioning) do
          [
            { "device" => "/dev/sda", "use" => "all", "partitions" => [root_spec, raid_spec] },
            { "device" => "/dev/md", "partitions" => [home_spec] }
          ]
        end

        let(:raid_options) { { "raid_name" => md_device, "raid_type" => "raid0" } }

        let(:home_spec) do
          {
            "mount" => "/home", "filesystem" => "xfs", "size" => "max",
            "raid_name" => md_device, "partition_nr" => 0, "raid_options" => raid_options,
            "create" => false
          }
        end

        let(:raid_spec) do
          { "raid_name" => md_device, "create" => false }
        end

        it "reuses a RAID" do
          proposal.propose
          devicegraph = proposal.devices
          expect(devicegraph.md_raids).to contain_exactly(
            an_object_having_attributes(
              "name"     => "/dev/md/md0",
              "md_level" => Y2Storage::MdLevel::RAID0
            )
          )
        end
      end

      # Regression test for bug#1098594
      context "installing in a BIOS-defined MD RAID" do
        let(:scenario) { "bug_1098594.xml" }

        let(:partitioning) do
          [
            {
              "device" => "/dev/md/Volume0_0", "use" => "3,4,9",
              "partitions" => [efi_spec, root_spec, swap_spec]
            }
          ]
        end

        let(:efi_spec) do
          {
            "mount" => "/boot/efi", "create" => false, "partition_nr" => 3, "format" => true,
            "filesystem" => "vfat", "mountby" => "uuid", "fstopt" => "umask=0002,utf8=true"
          }
        end

        let(:root_spec) do
          {
            "mount" => "/", "create" => false, "partition_nr" => 4, "format" => true,
            "filesystem" => "xfs", "mountby" => "uuid"
          }
        end

        let(:swap_spec) do
          {
            "mount" => "swap", "create" => false, "partition_nr" => 9, "format" => true,
            "filesystem" => "swap", "mountby" => "device", "fstopt" => "defaults"
          }
        end

        # bug#1098594, the partitions are on an Md (not a real disk), so when the code did
        #   partition.disk
        # it returned nil and produced an exception afterwards
        it "does not crash" do
          expect { proposal.propose }.to_not raise_error
        end

        it "formats the partitions of the RAID as requested" do
          proposal.propose
          devicegraph = proposal.devices

          expect(devicegraph.raids).to contain_exactly(
            an_object_having_attributes("name" => "/dev/md/Volume0_0")
          )

          part3 = devicegraph.find_by_name("/dev/md/Volume0_0p3")
          expect(part3.filesystem.mount_path).to eq "/boot/efi"
          expect(part3.filesystem.type).to eq Y2Storage::Filesystems::Type::VFAT

          part4 = devicegraph.find_by_name("/dev/md/Volume0_0p4")
          expect(part4.filesystem.mount_path).to eq "/"
          expect(part4.filesystem.type).to eq Y2Storage::Filesystems::Type::XFS

          part9 = devicegraph.find_by_name("/dev/md/Volume0_0p9")
          expect(part9.filesystem.mount_path).to eq "swap"
          expect(part9.filesystem.type).to eq Y2Storage::Filesystems::Type::SWAP
        end
      end
    end

    describe "LVM on RAID" do
      let(:partitioning) do
        [
          { "device" => "/dev/sda", "use" => "all", "partitions" => [raid_spec] },
          { "device" => "/dev/sdb", "use" => "all", "partitions" => [raid_spec] },
          { "device" => "/dev/md", "partitions" => [md_spec] },
          { "device" => "/dev/#{vg_name}", "partitions" => [root_spec, home_spec], "type" => :CT_LVM }
        ]
      end

      let(:md_spec) do
        {
          "partition_nr" => 1, "raid_options" => raid_options, "lvm_group" => vg_name
        }
      end

      let(:raid_options) do
        { "raid_type" => "raid0" }
      end

      let(:root_spec) do
        { "mount" => "/", "filesystem" => :ext4, "lv_name" => "root", "size" => "5G" }
      end

      let(:home_spec) do
        { "mount" => "/home", "filesystem" => :xfs, "lv_name" => "home", "size" => "5G" }
      end

      let(:raid_spec) do
        { "raid_name" => "/dev/md1", "size" => "20GB", "partition_id" => 253 }
      end

      it "creates a RAID to be used as PV" do
        proposal.propose
        devicegraph = proposal.devices
        expect(devicegraph.md_raids).to contain_exactly(
          an_object_having_attributes(
            "number"   => 1,
            "md_level" => Y2Storage::MdLevel::RAID0
          )
        )
        raid = devicegraph.md_raids.first
        expect(raid.lvm_pv.lvm_vg.vg_name).to eq(vg_name)
      end

      it "creates requested volume groups on top of the RAID device" do
        proposal.propose
        devicegraph = proposal.devices
        expect(devicegraph.lvm_vgs).to contain_exactly(
          an_object_having_attributes(
            "vg_name" => vg_name
          )
        )
        vg = devicegraph.lvm_vgs.first.lvm_pvs.first
        expect(vg.blk_device).to be_a(Y2Storage::Md)
      end

      it "creates requested logical volumes" do
        proposal.propose
        devicegraph = proposal.devices
        expect(devicegraph.lvm_lvs).to contain_exactly(
          an_object_having_attributes("lv_name" => "root", "filesystem_mountpoint" => "/"),
          an_object_having_attributes("lv_name" => "home", "filesystem_mountpoint" => "/home")
        )
      end
    end

    context "when already called" do
      before do
        proposal.propose
      end

      it "raises an error" do
        expect { proposal.propose }.to raise_error(Y2Storage::UnexpectedCallError)
      end
    end

    describe "boot partition" do
      let(:scenario) { "empty_hard_disk_50GiB" }

      let(:planned_boots) { [] }

      let(:boot_checker) do
        instance_double(Y2Storage::BootRequirementsChecker, needed_partitions: planned_boots)
      end

      before do
        allow(Y2Storage::BootRequirementsChecker).to receive(:new).and_return(boot_checker)
      end

      let(:partitioning) do
        [{ "use" => "all", "partitions" => [swap, root], "disklabel" => "gpt" }]
      end

      context "when a boot partition is required" do
        let(:planned_boots) { [planned_boot] }

        let(:planned_boot) do
          Y2Storage::Planned::Partition.new(nil).tap do |part|
            part.min_size = 1.MiB
            part.max_size = 1.MiB
            part.partition_id = Y2Storage::PartitionId::BIOS_BOOT
          end
        end

        it "creates the boot partition" do
          proposal.propose
          devicegraph = proposal.devices
          boot = devicegraph.partitions.find { |p| p.id == Y2Storage::PartitionId::BIOS_BOOT }
          expect(boot).to_not be_nil
        end
      end

      context "when a boot partition is not required" do
        let(:planned_boots) { [] }

        it "does not create a boot partition" do
          proposal.propose
          devicegraph = proposal.devices
          boot = devicegraph.partitions.find { |p| p.id == Y2Storage::PartitionId::BIOS_BOOT }
          expect(boot).to be_nil
        end
      end

      it "checks for boot partition after partition tables have been created" do
        expect(Y2Storage::BootRequirementsChecker).to receive(:new) do |devicegraph, _planned|
          disk = devicegraph.disks.first
          expect(disk.partition_table).to_not be_nil
          boot_checker
        end
        proposal.propose
      end
    end

    describe "partition table" do
      let(:root) { ROOT_PART.merge("create" => true, "size" => "max") }

      let(:swap) do
        { "filesystem" => :swap, "mount" => "swap", "size" => "1GB", "create" => true }
      end

      context "when does not exist" do
        let(:scenario) { "empty_hard_disk_50GiB" }

        context "and it is not defined in the profile" do
          let(:partitioning) do
            [{ "use" => "all", "partitions" => [swap, root] }]
          end

          it "creates a partition table of the preferred type" do
            proposal.propose
            devicegraph = proposal.devices
            disk = Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda")
            expect(disk.partition_table.type).to eq(disk.preferred_ptable_type)
          end
        end

        context "and it is defined in the profile" do
          let(:partitioning) do
            [{ "use" => "all", "partitions" => [swap, root], "disklabel" => "gpt" }]
          end

          it "creates a partition of the given type" do
            proposal.propose
            devicegraph = proposal.devices
            disk = Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda")
            expect(disk.partition_table.type).to eq(Y2Storage::PartitionTables::Type::GPT)
          end
        end
      end

      context "when does exist" do
        let(:scenario) { "windows-linux-free-pc" }
        let(:initialize_value) { false }
        let(:partitioning) do
          [
            {
              "use" => use, "partitions" => [swap, root], "disklabel" => "gpt",
              "initialize" => initialize_value
            }
          ]
        end

        context "and a different type is requested and 'initialize' element is set to 'true'" do
          let(:initialize_value) { true }
          let(:use) { "1,2" }

          it "creates a partition table of the given type" do
            proposal.propose
            devicegraph = proposal.devices
            disk = Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda")
            expect(disk.partition_table.type).to eq(Y2Storage::PartitionTables::Type::GPT)
          end
        end

        context "and a different type is requested and there are no partitions" do
          let(:use) { "all" }

          it "creates a partition table of the given type" do
            proposal.propose
            devicegraph = proposal.devices
            disk = Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda")
            expect(disk.partition_table.type).to eq(Y2Storage::PartitionTables::Type::GPT)
          end
        end

        context "and a different type is requested but there are partitions" do
          let(:use) { "1,2" }

          it "does not change the partition table" do
            proposal.propose
            devicegraph = proposal.devices
            disk = Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda")
            expect(disk.partition_table.type).to eq(Y2Storage::PartitionTables::Type::MSDOS)
          end
        end
      end
    end

    context "when there is not enough space" do
      let(:partitioning) do
        [{ "device" => "/dev/sda", "use" => "1,3", "partitions" => [root, home, var] }]
      end

      let(:root) { ROOT_PART.merge("size" => "150GiB", "create" => true) }

      let(:home) do
        { "filesystem" => :xfs, "mount" => "/home", "size" => "350GiB", "create" => true }
      end

      let(:var) do
        { "filesystem" => :xfs, "mount" => "/var", "size" => "150GiB", "create" => true }
      end

      it "reduces partitions proportionally" do
        proposal.propose
        devicegraph = proposal.devices
        home_dev, _swap, root_dev, var_dev = devicegraph.partitions.sort_by { |p| p.region.start }

        expect(home_dev).to have_attributes(filesystem_mountpoint: "/home", size: 250.GiB)
        expect(root_dev).to have_attributes(filesystem_mountpoint: "/")
        expect(var_dev).to have_attributes(filesystem_mountpoint: "/var")
        expect(root_dev.size).to eq(var_dev.size + 1.MiB)
        expect(root_dev.size + var_dev.size).to eq(248.GiB - 1.MiB)
      end

      it "adds an issue for each reduced partition" do
        proposal.propose
        issues = issues_list.select do |i|
          i.is_a?(Y2Storage::AutoinstIssues::ShrinkedPlannedDevices)
        end
        expect(issues.size).to eq(1)
      end

      it "sets missing space" do
        proposal.propose
        # shrinked devices: home, -100 GiB; root and var, -26 GiB each one.
        expect(proposal.missing_space).to eq(152.GiB + 1.MiB)
      end
    end
  end

  describe "#issues_list" do
    context "when a list was given" do
      it "returns the given list" do
        expect(proposal.issues_list).to eq(issues_list)
      end
    end

    context "when no list was given" do
      subject(:proposal) { described_class.new(partitioning: [], devicegraph: fake_devicegraph) }

      it "returns a new list" do
        expect(proposal.issues_list).to be_a(Y2Storage::AutoinstIssues::List)
      end
    end
  end
end
