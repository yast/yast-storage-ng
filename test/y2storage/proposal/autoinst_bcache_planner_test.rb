#!/usr/bin/env rspec
# encoding: utf-8

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

require_relative "../spec_helper"
require_relative "../../support/autoinst_devices_planner_btrfs"
require "y2storage/proposal/autoinst_bcache_planner"
require "y2storage/autoinst_issues/list"
require "y2storage/autoinst_profile/drive_section"

describe Y2Storage::Proposal::AutoinstBcachePlanner do
  using Y2Storage::Refinements::SizeCasts

  subject(:planner) { described_class.new(fake_devicegraph, issues_list) }
  let(:scenario) { "windows-linux-free-pc" }
  let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

  before do
    fake_scenario(scenario)
  end

  describe "#planned_devices" do
    let(:drive) { Y2Storage::AutoinstProfile::DriveSection.new_from_hashes(bcache) }
    let(:disklabel) { nil }

    let(:bcache) do
      {
        "device" => "/dev/bcache0", "disklabel" => disklabel,
        "partitions" => [root_spec]
      }
    end

    let(:root_spec) do
      { "mount" => "/", "filesystem" => "btrfs", "size" => "max" }
    end

    it "returns a planned Bcache device with the given device name" do
      bcache = planner.planned_devices(drive).first
      expect(bcache.name).to eq("/dev/bcache0")
    end

    context "when a partition table type is specified" do
      let(:disklabel) { "msdos" }

      it "returns a planned Bcache with partitions" do
        bcache = planner.planned_devices(drive).first
        expect(bcache.partitions).to contain_exactly(
          an_object_having_attributes("mount_point" => "/")
        )
      end

      it "sets the partition table" do
        bcache = planner.planned_devices(drive).first
        expect(bcache.ptable_type).to eq(Y2Storage::PartitionTables::Type.find("msdos"))
      end
    end

    context "when a partition table type is specified" do
      it "returns a planned Bcache with partitions" do
        bcache = planner.planned_devices(drive).first
        expect(bcache.partitions).to contain_exactly(
          an_object_having_attributes("mount_point" => "/")
        )
      end

      it "does not set the partition table type" do
        bcache = planner.planned_devices(drive).first
        expect(bcache.ptable_type).to be_nil
      end
    end

    context "when the partition table type is set to 'none'" do
      let(:disklabel) { "none" }

      it "returns a planned Bcache with filesystem settings (no partitions)" do
        md = planner.planned_devices(drive).first
        expect(md.mount_point).to eq("/")
        expect(md.filesystem_type).to eq(Y2Storage::Filesystems::Type::BTRFS)
      end

      it "does not set the partition table type" do
        bcache = planner.planned_devices(drive).first
        expect(bcache.ptable_type).to be_nil
      end
    end

    context "snapshots"
  end
end
