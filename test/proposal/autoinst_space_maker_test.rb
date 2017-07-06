#!/usr/bin/env rspec
#
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
require "y2storage/proposal/autoinst_space_maker"

describe Y2Storage::Proposal::AutoinstSpaceMaker do
  subject(:space_maker) { described_class.new(analyzer) }

  let(:analyzer) { Y2Storage::DiskAnalyzer.new(fake_devicegraph) }
  let(:scenario) { "windows-linux-free-pc" }
  let(:partitioning_array) { [{ "device" => "/dev/sda", "use" => "all" }] }
  let(:partitioning) do
    Y2Storage::AutoinstProfile::PartitioningSection.new_from_hashes(partitioning_array)
  end
  let(:drives_map) { Y2Storage::Proposal::AutoinstDrivesMap.new(fake_devicegraph, partitioning) }

  before { fake_scenario(scenario) }

  describe "#clean_devicegraph" do
    context "when 'use' key is set to 'all'" do
      it "removes all partitions" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map)
        expect(devicegraph.partitions).to be_empty
      end

      it "does not remove the partition table" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map)
        devicegraph.partitions
        disk = Y2Storage::Disk.find_by_name(devicegraph, "/dev/sda")
        expect(disk.partition_table).to_not be_nil
      end
    end

    context "when 'use' key is set to 'linux'" do
      it "removes only Linux partitions" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map)
        expect(devicegraph.partitions).to be_empty
      end
    end

    context "when 'initialize' key is set to true" do
      let(:partitioning_array) { [{ "device" => "/dev/sda", "initialize" => true }] }

      it "remove all partitions" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map)
        expect(devicegraph.partitions).to be_empty
      end

      it "removes the partitions table" do
        devicegraph = subject.cleaned_devicegraph(fake_devicegraph, drives_map)
        devicegraph.partitions
        disk = Y2Storage::Disk.find_by_name(devicegraph, "/dev/sda")
        expect(disk.partition_table).to be_nil
      end
    end

    context "when some given drive does not exist" do
      let(:partitioning_array) { [{ "device" => "/dev/sdx", "use" => "all" }] }

      it "ignores the device" do
        expect { subject.cleaned_devicegraph(fake_devicegraph, drives_map) }.to_not raise_error
      end
    end
  end
end
