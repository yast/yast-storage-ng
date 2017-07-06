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
  subject(:drives_map) { described_class.new(fake_devicegraph, partitioning) }

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

  before { fake_scenario(scenario) }

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
