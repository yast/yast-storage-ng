#!/usr/bin/env rspec

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
  subject(:proposal) do
    described_class.new(
      partitioning: partitioning, devicegraph: fake_devicegraph, issues_list: issues_list
    )
  end

  let(:issues_list) { ::Installation::AutoinstIssues::List.new }

  before do
    allow(Yast::Mode).to receive(:auto).and_return(true)
  end

  describe "#propose" do
    before { fake_scenario(scenario) }
    let(:scenario) { "bug_1120979" }

    let(:partitioning) do
      [
        {
          "device" => drive_device,
          "type" => :CT_MD, "use" => "all", "disklabel" => "msdos",
          "partitions" =>
            [
              {
                "create" => create, "filesystem" => :xfs, "format" => create, "mount" => "/home",
                "mountby" => :uuid, "partition_nr" => partition_nr,
                "raid_options" => {
                  "raid_type"    => "raid1",
                  "device_order" => ["/dev/vdb1", "/dev/vdc1"]
                }
              }
            ]
        },
        {
          "device" => "/dev/vda",
          "type" => :CT_DISK, "use" => "all", "initialize" => true, "disklabel" => "msdos",
          "partitions" =>
            [
              {
                "create" => true, "filesystem" => :swap, "format" => true, "mount" => "swap",
                "mountby" => :uuid, "partition_nr" => 1, "partition_id" => 130,
                "size" => 1553104384
              },
              {
                "create" => true, "filesystem" => :btrfs, "format" => true, "mount" => "/",
                "mountby" => :uuid, "partition_nr" => 2, "partition_id" => 131,
                "size" => 19904232960
              }
            ]
        },
        {
          "device" => "/dev/vdb",
          "type" => :CT_DISK, "use" => "all", "disklabel" => "msdos",
          "partitions" =>
            [
              {
                "create" => create_vdb1, "format" => create, "mountby" => :device,
                "partition_nr" => 1, "partition_id" => 253, "raid_name" => md_name_in_profile
              }
            ]
        },
        {
          "device" => "/dev/vdc",
          "type" => :CT_DISK, "use" => "all", "disklabel" => "msdos",
          "partitions" =>
            [
              {
                "create" => create_vdc1, "format" => create, "mountby" => :device,
                "partition_nr" => 1, "partition_id" => 253, "raid_name" => md_name_in_profile
              }
            ]
        }
      ]
    end

    RSpec.shared_examples "format MD with no issues" do
      it "does not register any issue" do
        proposal.propose
        expect(issues_list).to be_empty
      end

      it "formats the RAID as specified in the profile" do
        proposal.propose
        raid = proposal.devices.raids.first
        expect(raid.filesystem.type).to eq Y2Storage::Filesystems::Type::XFS
        expect(raid.filesystem.mount_path).to eq "/home"
      end
    end

    RSpec.shared_examples "reuse Md" do
      it "keeps the existing RAID and its devices" do
        raid_sid = fake_devicegraph.raids.first.sid

        proposal.propose
        raids = proposal.devices.raids

        expect(raids.size).to eq 1
        expect(raids.first.sid).to eq raid_sid
        expect(raids.first.devices.map(&:name)).to contain_exactly("/dev/vdb1", "/dev/vdc1")
      end

      include_examples "format MD with no issues"
    end

    RSpec.shared_examples "missing Md" do
      it "registers a MissingReusableDevice issue" do
        proposal.propose
        issues = issues_list.to_a

        expect(issues.size).to eq 1
        expect(issues.first).to be_a(Y2Storage::AutoinstIssues::MissingReusableDevice)
      end
    end

    RSpec.shared_examples "recreate Md" do
      it "creates a new RAID with the specified devices" do
        raid_sid = fake_devicegraph.raids.first.sid

        proposal.propose

        raids = proposal.devices.raids
        expect(raids.size).to eq 1

        raid = raids.first
        expect(raid.sid).to_not eq raid_sid
        expect(raid.md_level).to eq Y2Storage::MdLevel::RAID1
        expect(raid.sorted_devices.map(&:name)).to eq ["/dev/vdb1", "/dev/vdc1"]
      end

      include_examples "format MD with no issues"
    end

    RSpec.shared_examples "reuse partitions" do
      it "reuses the block devices" do
        vdb1_sid = fake_devicegraph.find_by_name("/dev/vdb1").sid
        vdc1_sid = fake_devicegraph.find_by_name("/dev/vdc1").sid

        proposal.propose
        vdb1 = proposal.devices.find_by_name("/dev/vdb1")
        vdc1 = proposal.devices.find_by_name("/dev/vdc1")

        expect(vdb1.sid).to eq vdb1_sid
        expect(vdc1.sid).to eq vdc1_sid
      end
    end

    RSpec.shared_examples "recreate partitions" do
      it "recreates the block devices as requested" do
        vdb1_sid = fake_devicegraph.find_by_name("/dev/vdb1").sid
        vdc1_sid = fake_devicegraph.find_by_name("/dev/vdc1").sid

        proposal.propose
        vdb1 = proposal.devices.find_by_name("/dev/vdb1")
        vdc1 = proposal.devices.find_by_name("/dev/vdc1")

        expect(vdb1.sid).to_not eq vdb1_sid
        expect(vdc1.sid).to_not eq vdc1_sid
      end
    end

    RSpec.shared_examples "all MD create/reuse combinations" do
      # Regression test for bsc#1120979 and bsc#1121720, since libstorage-ng
      # uses names like /dev/md/0 and Planned::Md did use /dev/md0, reusing
      # MDs failed in several scenarios.
      context "when reusing an existing Md" do
        let(:create) { false }
        let(:create_vdb1) { false }
        let(:create_vdc1) { false }

        before do
          # Mock the system lookup performed as last resort to find a device
          allow(Y2Storage::BlkDevice).to receive(:find_by_any_name)
        end

        context "if raid_name is specified as /dev/mdX" do
          context "and the MD exists" do
            let(:md_name_in_profile) { "/dev/md0" }
            include_examples "reuse Md"
          end

          context "and the MD does not exist" do
            let(:md_name_in_profile) { "/dev/md1" }
            include_examples "missing Md"
          end
        end

        context "if raid_name is specified as /dev/md/X" do
          context "and the MD exists" do
            let(:md_name_in_profile) { "/dev/md/0" }
            include_examples "reuse Md"
          end

          context "and the MD does not exist" do
            let(:md_name_in_profile) { "/dev/md/1" }
            include_examples "missing Md"
          end
        end
      end

      context "when re-creating an Md instead of reusing the existing one" do
        let(:create) { true }

        context "reusing the block devices of the original MD" do
          let(:create_vdb1) { false }
          let(:create_vdc1) { false }

          context "if raid_name is specified as /dev/mdX" do
            let(:md_name_in_profile) { "/dev/md0" }

            include_examples "recreate Md"
            include_examples "reuse partitions"
          end

          context "if raid_name is specified as /dev/md/X" do
            let(:md_name_in_profile) { "/dev/md/0" }

            include_examples "recreate Md"
            include_examples "reuse partitions"
          end
        end

        context "re-creating the block devices of the original MD" do
          let(:create_vdb1) { true }
          let(:create_vdc1) { true }

          context "if raid_name is specified as /dev/mdX" do
            let(:md_name_in_profile) { "/dev/md0" }

            include_examples "recreate Md"
            include_examples "recreate partitions"
          end

          context "if raid_name is specified as /dev/md/X" do
            let(:md_name_in_profile) { "/dev/md/0" }

            include_examples "recreate Md"
            include_examples "recreate partitions"
          end
        end
      end
    end

    context "with current libstorage-ng behavior (Md#name like /dev/md/0)" do
      context "and a classic profile (using /dev/md in <device>)" do
        let(:drive_device) { "/dev/md" }
        let(:partition_nr) { md_name_in_profile[-1].to_i }

        include_examples "all MD create/reuse combinations"
      end

      context "and a profile using the whole MD name in <device>" do
        let(:drive_device) { md_name_in_profile }
        let(:partition_nr) { 0 }

        include_examples "all MD create/reuse combinations"
      end
    end

    context "with libstorage-ng reporting Md#name with format like /dev/md0" do
      before do
        fake_devicegraph.find_by_name("/dev/md/0").name = "/dev/md0"
      end

      context "and a classic profile (using /dev/md in <device>)" do
        let(:drive_device) { "/dev/md" }
        let(:partition_nr) { md_name_in_profile[-1].to_i }

        include_examples "all MD create/reuse combinations"
      end

      context "and a profile using the whole MD name in <device>" do
        let(:drive_device) { md_name_in_profile }
        let(:partition_nr) { 0 }

        include_examples "all MD create/reuse combinations"
      end
    end
  end
end
