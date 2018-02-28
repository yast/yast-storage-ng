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
  subject(:section) { described_class.new }
  let(:sda) { { "device" => "/dev/sda", "use" => "linux" } }
  let(:sdb) { { "device" => "/dev/sdb", "use" => "all" } }
  let(:disk_section) { instance_double(Y2Storage::AutoinstProfile::DriveSection) }
  let(:dasd_section) { instance_double(Y2Storage::AutoinstProfile::DriveSection) }
  let(:vg_section) { instance_double(Y2Storage::AutoinstProfile::DriveSection) }
  let(:partitioning) { [sda, sdb] }

  describe ".new_from_hashes" do
    before do
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_hashes)
        .with(sda, Y2Storage::AutoinstProfile::PartitioningSection).and_return(disk_section)
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_hashes)
        .with(sdb, Y2Storage::AutoinstProfile::PartitioningSection).and_return(dasd_section)
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
        .with(sda, Y2Storage::AutoinstProfile::PartitioningSection).and_return(nil)

      section = described_class.new_from_hashes(partitioning)
      expect(section.drives).to eq([dasd_section])
    end
  end

  describe ".new_from_storage" do
    let(:devicegraph) do
      instance_double(Y2Storage::Devicegraph, disk_devices: disks, lvm_vgs: [vg])
    end
    let(:disks) { [disk, dasd] }
    let(:disk) { instance_double(Y2Storage::Disk) }
    let(:dasd) { instance_double(Y2Storage::Dasd) }
    let(:vg) { instance_double(Y2Storage::LvmVg) }

    before do
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_storage)
        .with(disk).and_return(disk_section)
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_storage)
        .with(dasd).and_return(dasd_section)
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_storage)
        .with(vg).and_return(vg_section)
    end

    it "returns a new PartitioningSection object" do
      expect(described_class.new_from_storage(devicegraph)).to be_a(described_class)
    end

    it "creates an entry in #drives for every relevant VG, disk and DASD" do
      section = described_class.new_from_storage(devicegraph)
      expect(section.drives).to eq([vg_section, disk_section, dasd_section])
    end

    it "ignores irrelevant drives" do
      allow(Y2Storage::AutoinstProfile::DriveSection).to receive(:new_from_storage)
        .with(disk).and_return(nil)
      section = described_class.new_from_storage(devicegraph)
      expect(section.drives).to eq([vg_section, dasd_section])
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

  describe "filtered drives lists" do
    subject(:section) { described_class.new }
    let(:drive1) { double("DriveSection", device: "/dev/sda", type: :CT_DISK) }
    let(:drive2) { double("DriveSection", device: "/dev/sdb", type: :CT_DISK) }
    let(:drive3) { double("DriveSection", device: "/dev/vg0", type: :CT_LVM) }
    let(:drive4) { double("DriveSection", device: "/dev/vg1", type: :CT_LVM) }
    let(:drive5) { double("DriveSection", device: "/dev/md", type: :CT_MD) }
    let(:drive6) { double("DriveSection", device: "/dev/md", type: :CT_MD) }
    let(:drive7) { double("DriveSection", type: :CT_DISK) }
    let(:wrongdrv1) { double("DriveSection", device: "/dev/md", type: :CT_DISK) }
    let(:wrongdrv2) { double("DriveSection", device: "/dev/sdc", type: :CT_MD) }
    let(:wrongdrv3) { double("DriveSection", device: "/dev/sdd", type: :CT_WRONG) }
    let(:wrongdrv4) { double("DriveSection", type: :CT_LVM) }
    let(:wrongdrv5) { double("DriveSection", type: :CT_MD) }

    before do
      section.drives = [
        drive1, drive2, drive3, drive4, drive5, drive6, drive7,
        wrongdrv1, wrongdrv2, wrongdrv3, wrongdrv4, wrongdrv5
      ]
    end

    describe "#disk_drives" do
      it "returns drives which type is :CT_DISK, even if they look invalid" do
        expect(section.disk_drives).to contain_exactly(drive1, drive2, drive7, wrongdrv1)
      end
    end

    describe "#lvm_drives" do
      it "returns drives which type is :CT_LVM, even if they look invalid" do
        expect(section.lvm_drives).to contain_exactly(drive3, drive4, wrongdrv4)
      end
    end

    describe "#md_drives" do
      it "returns drives which type is :CT_MD, even if they look invalid" do
        expect(section.md_drives).to contain_exactly(drive5, drive6, wrongdrv2, wrongdrv5)
      end

      it "does not include drives of other types with device='/dev/md'" do
        expect(section.md_drives).to_not include wrongdrv1
      end
    end
  end

  describe "#section_name" do
    it "returns 'partitioning'" do
      expect(section.section_name).to eq("partitioning")
    end
  end

  describe "#parent" do
    it "returns nil" do
      expect(section.parent).to be_nil
    end
  end
end
