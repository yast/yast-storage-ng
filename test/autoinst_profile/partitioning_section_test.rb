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
require "y2storage"

describe Y2Storage::AutoinstProfile::PartitioningSection do
  let(:sda) { { "device" => "/dev/sda", "use" => "linux" } }
  let(:sdb) { { "device" => "/dev/sdb", "use" => "all" } }
  let(:disk_section) { instance_double(Y2Storage::AutoinstProfile::DriveSection) }
  let(:dasd_section) { instance_double(Y2Storage::AutoinstProfile::DriveSection) }
  let(:partitioning) { [sda, sdb] }

  describe ".new_from_hashes" do
    before do
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_hashes)
        .with(sda).and_return(disk_section)
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_hashes)
        .with(sdb).and_return(dasd_section)
    end

    it "returns a new PartitioningSection object" do
      expect(described_class.new_from_hashes(partitioning)).to be_a(described_class)
    end

    it "creates an entry in #drives for every valid hash in the array" do
      section = described_class.new_from_hashes(partitioning)
      expect(section.drives).to eq([disk_section, dasd_section])
    end

    # In fact, I don't think DriveSection.new_from_hashes can return nil, but
    # just in case...
    it "ignores hashes that couldn't be converted into DriveSection objects" do
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_hashes)
        .with(sda).and_return(nil)

      section = described_class.new_from_hashes(partitioning)
      expect(section.drives).to eq([dasd_section])
    end
  end

  describe ".new_from_storage" do
    let(:devicegraph) { instance_double(Y2Storage::Devicegraph, disk_devices: disks) }
    let(:disks) { [disk, dasd] }
    let(:disk) { instance_double(Y2Storage::Disk) }
    let(:dasd) { instance_double(Y2Storage::Dasd) }

    before do
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_storage)
        .with(disk).and_return(disk_section)
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_storage)
        .with(dasd).and_return(dasd_section)
    end

    it "returns a new PartitioningSection object" do
      expect(described_class.new_from_storage(devicegraph)).to be_a(described_class)
    end

    it "creates an entry in #drives for every relevant disk and DASD" do
      section = described_class.new_from_storage(devicegraph)
      expect(section.drives).to eq([disk_section, dasd_section])
    end

    it "ignores irrelevant drives" do
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_storage)
        .with(disk).and_return(nil)
      section = described_class.new_from_storage(devicegraph)
      expect(section.drives).to eq([dasd_section])
    end
  end

  describe "#to_hashes" do
    subject(:section) { described_class.new_from_hashes(partitioning) }

    it "returns an array of hashes" do
      expect(subject.to_hashes).to be_a(Array)
      expect(subject.to_hashes).to all(be_a(Hash))
    end

    it "includes a hash for every drive" do
      hashes = subject.to_hashes
      device_names = hashes.map { |h| h["device"] }
      expect(device_names).to eq(["/dev/sda", "/dev/sdb"])
    end
  end
end
