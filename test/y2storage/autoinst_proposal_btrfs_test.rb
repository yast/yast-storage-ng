#!/usr/bin/env rspec
# encoding: utf-8
#
# Copyright (c) [2019] SUSE LLC
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
require "y2storage"

describe Y2Storage::AutoinstProposal do
  before do
    fake_scenario(scenario)

    allow(Yast::Mode).to receive(:auto).and_return(true)
  end

  subject(:proposal) do
    described_class.new(
      partitioning: partitioning, devicegraph: fake_devicegraph, issues_list: issues_list
    )
  end

  describe "#propose" do
    before do
      # This should not be needed, but for some reason, Devicegraph#check fails with the devicegraph
      # defined in "btrfs2-devicegraph.xml". The check passes after removing all partitions from
      # "/dev/sda". Note that removing those partitions does not affect the result of tests here.
      sda = fake_devicegraph.find_by_name("/dev/sda")
      sda.delete_partition_table
    end

    let(:scenario) { "btrfs2-devicegraph.xml" }

    let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

    let(:partitioning) do
      [
        {
          "device" => "/dev/sdb",
          "type" => :CT_DISK, "use" => "all", "initialize" => true, "disklabel" => "gpt",
          "partitions" =>
            [
              {
                "create" => create_sdb1, "size" => "1.5GiB", "format" => false, "partition_nr" => 1,
                "btrfs_name" => "root_fs"
              }
            ]
        },
        {
          "device" => "/dev/sdc",
          "type" => :CT_DISK, "use" => "all", "initialize" => true, "disklabel" => "gpt",
          "partitions" =>
            [
              {
                "create" => create_sdc1, "size" => "1.5GiB", "format" => false, "partition_nr" => 1,
                "btrfs_name" => "root_fs"
              }
            ]
        },
        {
          "device" => "root_fs", "type" => :CT_BTRFS,
          "partitions" =>
            [
              {
                "create" => create_btrfs, "uuid" => uuid, "mount" => "/", "mountby" => :uuid
              }
            ],
          "btrfs_options" =>
            {
              "data_raid_level"     => "single",
              "metadata_raid_level" => "raid10"
            }
        }
      ]
    end

    let(:uuid) { "" }

    context "when creating a multi-device Btrfs" do
      let(:create_btrfs) { true }

      let(:create_sdb1) { true }

      let(:create_sdc1) { false }

      it "creates a new multi-device Btrfs over the specified devices" do
        filesystem_sid = fake_devicegraph.multidevice_btrfs_filesystems.first.sid

        proposal.propose
        multidevice_btrfs_filesystems = proposal.devices.multidevice_btrfs_filesystems

        expect(multidevice_btrfs_filesystems.size).to eq(1)

        filesystem = multidevice_btrfs_filesystems.first

        expect(filesystem.sid).to_not eq filesystem_sid
        expect(filesystem.blk_devices.map(&:name)).to contain_exactly("/dev/sdb1", "/dev/sdc1")
      end

      it "creates a multi-device Btrfs with the specified options" do
        proposal.propose
        filesystem = proposal.devices.multidevice_btrfs_filesystems.first

        expect(filesystem.mount_path).to eq("/")
        expect(filesystem.mount_point.mount_by.is?(:uuid)).to eq(true)

        expect(filesystem.data_raid_level.is?(:single)).to eq(true)
        expect(filesystem.metadata_raid_level.is?(:raid10)).to eq(true)
      end
    end

    context "when reusing an existing multi-device Btrfs" do
      let(:create_btrfs) { false }

      let(:create_sdb1) { false }

      let(:create_sdc1) { false }

      context "and the filesystem cannot be found by the given UUID" do
        let(:uuid) { "not-found" }

        it "registers a MissingReusableDevice issue" do
          proposal.propose
          issues = issues_list.to_a

          expect(issues.any? { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingReusableDevice) })
            .to eq(true)
        end
      end

      context "and the filesystem exists" do
        let(:uuid) { "b7b96325-feb5-4e7e-a7f4-014ce2402e71" }

        it "keeps the existing filesystem and its devices" do
          filesystem_sid = fake_devicegraph.multidevice_btrfs_filesystems.first.sid

          proposal.propose
          multidevice_btrfs_filesystems = proposal.devices.multidevice_btrfs_filesystems

          expect(multidevice_btrfs_filesystems.size).to eq(1)
          expect(multidevice_btrfs_filesystems.first.sid).to eq(filesystem_sid)
          expect(multidevice_btrfs_filesystems.first.blk_devices.map(&:name))
            .to contain_exactly("/dev/sdb1", "/dev/sdc1", "/dev/sdd1", "/dev/sde1")
        end

        it "assigns the specified options to the filesystem" do
          proposal.propose
          filesystem = proposal.devices.multidevice_btrfs_filesystems.first

          expect(filesystem.mount_path).to eq("/")
          expect(filesystem.mount_point.mount_by.is?(:uuid)).to eq(true)
        end

        it "does not change the data RAID level" do
          proposal.propose
          filesystem = proposal.devices.multidevice_btrfs_filesystems.first

          expect(filesystem.data_raid_level.is?(:raid0)).to eq(true)
        end

        it "does not change the meta-data RAID level" do
          proposal.propose
          filesystem = proposal.devices.multidevice_btrfs_filesystems.first

          expect(filesystem.metadata_raid_level.is?(:raid1)).to eq(true)
        end
      end
    end
  end
end
