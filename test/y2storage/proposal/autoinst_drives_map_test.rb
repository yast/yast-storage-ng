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
require "y2storage/proposal/autoinst_drives_map"

describe Y2Storage::Proposal::AutoinstDrivesMap do
  subject(:drives_map) { described_class.new(fake_devicegraph, partitioning, issues_list) }

  let(:scenario) { "windows-linux-free-pc" }
  let(:partitioning_array) do
    [
      { "device" => "/dev/sda", "use" => "all" },
      { "use" => "all" },
      { "device" => "/dev/system", "type" => :CT_LVM }
    ]
  end
  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(partitioning_array)
  end
  let(:issues_list) do
    Y2Storage::AutoinstIssues::List.new
  end

  before { fake_scenario(scenario) }

  describe ".new" do
    context "when a device does not exist" do
      let(:partitioning_array) do
        [{ "device" => "/dev/sdx", "use" => "all" }]
      end

      it "registers an issue" do
        expect(issues_list).to be_empty
        described_class.new(fake_devicegraph, partitioning, issues_list)
        issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::NoDisk) }
        expect(issue).to_not be_nil
      end
    end

    context "when a suitable device does not exist" do
      let(:skip_list) do
        [
          { "skip_key" => "name", "skip_value" => "sda" },
          { "skip_key" => "name", "skip_value" => "sdb" }
        ]
      end

      let(:partitioning_array) do
        [{ "use" => "all", "skip_list" => skip_list }]
      end

      it "registers an issue" do
        expect(issues_list).to be_empty
        described_class.new(fake_devicegraph, partitioning, issues_list)
        issue = issues_list.find { |i| i.is_a?(Y2Storage::AutoinstIssues::NoDisk) }
        expect(issue).to_not be_nil
      end
    end

    context "when a disk udev link is used" do
      let(:root_by_label) do
        Y2Storage::BlkDevice.find_by_name(fake_devicegraph, "/dev/sda3")
      end

      let(:partitioning_array) do
        [{ "device" => "/dev/disk/by-label/root" }]
      end

      before do
        allow(Y2Storage::BlkDevice).to receive(:find_by_udev_link)
          .with(fake_devicegraph, "/dev/disk/by-label/root").and_return(root_by_label)
      end

      it "uses its kernel name" do
        described_class.new(fake_devicegraph, partitioning, issues_list)
        expect(drives_map.disk_names).to eq(["/dev/sda3"])
      end
    end
  end

  describe "#each" do
    it "executes the given block for each name/drive in the map" do
      drives = partitioning.drives
      expect { |i| drives_map.each(&i) }.to yield_successive_args(
        ["/dev/sda", drives[0]], ["/dev/sdb", drives[1]], ["/dev/system", drives[2]]
      )
    end

    context "when some device is on a skip list" do
      let(:partitioning_array) do
        [
          { "use" => "all", "skip_list" => [{ "skip_key" => "device", "skip_value" => "/dev/sda" }] }
        ]
      end

      it "ignores the given device" do
        expect do |probe|
          drives_map.each(&probe)
        end.to yield_successive_args(["/dev/sdb", partitioning.drives[0]])
      end
    end

    context "when no suitable drive is found" do
      let(:partitioning_array) do
        [
          { "device" => "/dev/sda", "use" => "all" },
          { "device" => "/dev/sdb", "use" => "all" },
          { "use" => "all" }
        ]
      end

      it "error?"
    end
  end

  describe "#disk_names" do
    let(:partitioning_array) do
      [
        { "device" => "/dev/sda", "use" => "all" },
        { "device" => "/dev/system", "type" => :CT_LVM }
      ]
    end

    it "return disk names" do
      expect(drives_map.disk_names).to eq(["/dev/sda", "/dev/system"])
    end
  end

  describe "#partitions?" do
    context "when partitioning does not define partitions for any device" do
      let(:partitioning_array) do
        [
          { "device" => "/dev/sda", "use" => "all" },
          { "device" => "/dev/sdb", "use" => "all" }
        ]
      end

      it "returns false" do
        expect(drives_map.partitions?).to eq(false)
      end
    end

    context "when partitioning defines partitions for some device" do
      let(:partitioning_array) do
        [
          { "device" => "/dev/sda", "use" => "all", "partitions" => [{ "mount" => "/" }] },
          { "device" => "/dev/sdb", "use" => "all" }
        ]
      end

      it "returns true" do
        expect(drives_map.partitions?).to eq(true)
      end
    end
  end
end
