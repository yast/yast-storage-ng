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
  subject(:proposal) do
    described_class.new(
      partitioning: partitioning, devicegraph: fake_devicegraph, issues_list: issues_list
    )
  end

  let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

  before do
    allow(Yast::Mode).to receive(:auto).and_return(true)
  end

  describe "#propose" do
    before { fake_scenario(scenario) }
    let(:scenario) { "pieter" }

    let(:partitioning) do
      [
        {
          "device" => "/dev/md",
          "type" => :CT_MD, "use" => "all", "disklabel" => "msdos", 
          "partitions" =>
            [
              {
                "create" => create, "filesystem" => :xfs, "format" => create, "mount" => "/home",
                "mountby" => :uuid, "partition_nr" => 0,
                "raid_options" => { "raid_type" => "raid1" }
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
                "create" => false, "format" => create, "mountby" => :device,
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
                "create" => false, "format" => create, "mountby" => :device,
                "partition_nr" => 1, "partition_id" => 253, "raid_name" => md_name_in_profile
              }
            ]
        },
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

    context "when reusing an existing Md" do
      let(:create) { false }

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

      context "if raid_name is specified as /dev/mdX" do
        let(:md_name_in_profile) { "/dev/md0" }

        include_examples "reuse Md"
      end

      context "if raid_name is specified as /dev/md/X" do
        let(:md_name_in_profile) { "/dev/md/0" }

        include_examples "reuse Md"
      end
    end

    context "when re-creating an Md instead of reusing the existing one" do
      let(:create) { true }

      RSpec.shared_examples "recreate Md" do
        it "creates a new RAID with the specified devices" do
          raid_sid = fake_devicegraph.raids.first.sid

          proposal.propose
          raids = proposal.devices.raids

          expect(raids.size).to eq 1
          expect(raids.first.sid).to_not eq raid_sid
          expect(raids.first.devices.map(&:name)).to contain_exactly("/dev/vdb1", "/dev/vdc1")
        end

        include_examples "format MD with no issues"
      end

      context "if raid_name is specified as /dev/mdX" do
        let(:md_name_in_profile) { "/dev/md0" }

        include_examples "recreate Md"
      end

      context "if raid_name is specified as /dev/md/X" do
        let(:md_name_in_profile) { "/dev/md/0" }

        include_examples "recreate Md"
      end
    end
  end
end
