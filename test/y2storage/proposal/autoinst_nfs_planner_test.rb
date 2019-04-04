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
require "y2storage/proposal/autoinst_nfs_planner"
require "y2storage/autoinst_issues/list"
require "y2storage/autoinst_profile/drive_section"

describe Y2Storage::Proposal::AutoinstNfsPlanner do
  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "empty_hard_disk_15GiB" }

  subject(:planner) { described_class.new(fake_devicegraph, issues_list) }

  let(:issues_list) { Y2Storage::AutoinstIssues::List.new }

  describe "#planned_devices" do
    let(:drive) { Y2Storage::AutoinstProfile::DriveSection.new_from_hashes(drive_section) }

    let(:drive_section) { { "device" => "/dev/nfs", "partitions" => [partition_section] } }

    context "when the partition section does not contain a device value" do
      let(:partition_section) do
        { "mount" => "/", "fstopt" => "rw,wsize=8192" }
      end

      it "does not plan a NFS filesystem" do
        expect(planner.planned_devices(drive)).to be_empty
      end

      it "registers an issue" do
        planner.planned_devices(drive)
        issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingValue) }

        expect(issue).to_not be_nil
        expect(issue.attr).to eq(:device)
      end
    end

    context "when the partition section does not contain a mount value" do
      let(:partition_section) do
        { "device" => "192.168.56.1:/root_fs", "fstopt" => "rw,wsize=8192" }
      end

      it "does not plan a NFS filesystem" do
        expect(planner.planned_devices(drive)).to be_empty
      end

      it "registers an issue" do
        planner.planned_devices(drive)
        issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::MissingValue) }

        expect(issue).to_not be_nil
        expect(issue.attr).to eq(:mount)
      end
    end

    context "when the partition section contains a device and a mount value" do
      let(:partition_section) do
        { "mount" => "/", "device" => "192.168.56.1:/root_fs", "fstopt" => fstopt }
      end

      let(:fstopt) { nil }

      it "plans a NFS filesystem" do
        expect(planner.planned_devices(drive)).to_not be_empty
      end

      it "sets the server" do
        planned_nfs = planner.planned_devices(drive).first

        expect(planned_nfs.server).to eq("192.168.56.1")
      end

      it "sets the shared path" do
        planned_nfs = planner.planned_devices(drive).first

        expect(planned_nfs.path).to eq("/root_fs")
      end

      it "sets the mount point" do
        planned_nfs = planner.planned_devices(drive).first

        expect(planned_nfs.mount_point).to eq("/")
      end

      it "does not register an issue" do
        planner.planned_devices(drive)

        expect(issues_list).to be_empty
      end

      context "and the fstab options are not given" do
        let(:fstopt) { nil }

        it "does not set the fstab options" do
          planned_nfs = planner.planned_devices(drive).first

          expect(planned_nfs.fstab_options).to be_empty
        end
      end

      context "and the fstab options are given" do
        let(:fstopt) { "rw,wsize=8192" }

        it "sets the fstab options" do
          planned_nfs = planner.planned_devices(drive).first

          expect(planned_nfs.fstab_options).to contain_exactly("rw", "wsize=8192")
        end
      end
    end
  end
end
