#!/usr/bin/env rspec
# encoding: utf-8
#
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

describe Y2Storage::AutoinstProfile::SkipListValue do
  subject(:value) { described_class.new(disk) }

  let(:scenario) { "windows-linux-free-pc" }
  let(:disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }

  before do
    fake_scenario(scenario)
  end

  describe "#size_k" do
    it "returns the size in kilobytes" do
      expect(value.size_k).to eq(disk.size.to_i)
    end
  end

  describe "#device" do
    it "returns the full device name" do
      expect(value.device).to eq("/dev/sda")
    end
  end

  describe "#name" do
    it "returns the device name" do
      expect(value.name).to eq("sda")
    end
  end

  describe "#method_missing" do
    let(:hwinfo) { OpenStruct.new(driver: ["ahci"]) }

    before do
      allow(disk).to receive(:hwinfo).and_return(hwinfo)
    end

    context "when a method is not defined" do
      context "but is available in the associated hwinfo object" do
        it "returns value from hwinfo" do
          expect(value.driver).to eq(hwinfo.driver)
        end
      end

      context "and is not available in the associated hwinfo object" do
        it "raises NoMethodError" do
          expect { value.other }.to raise_error(NoMethodError)
        end
      end
    end
  end

  describe "#label" do
    it "returns partitions table type" do
      expect(value.label).to eq("msdos")
    end

    context "when there is no partition table"
  end

  describe "#max_primary" do
    it "returns partitions table type" do
      expect(value.max_primary).to eq(4)
    end

    context "when there is no partition table"
  end

  describe "#max_logical" do
    it "returns partitions table type" do
      expect(value.max_logical).to eq(256)
    end

    context "when there is no partition table"
  end

  describe "#dasd_format" do
    let(:scenario) { "dasd_50GiB" }
    let(:disk) { Y2Storage::Dasd.find_by_name(fake_devicegraph, "/dev/sda") }

    it "returns format" do
      expect(value.dasd_format).to eq("none")
    end

    context "when device is not dasd" do
      let(:scenario) { "windows-linux-free-pc" }
      let(:disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }

      it "returns nil" do
        expect(value.dasd_format).to be_nil
      end
    end
  end

  describe "#transport" do
    it "returns transport" do
      expect(value.transport).to eq("unknown")
    end
  end

  describe "#sector_size" do
    it "returns block size" do
      expect(value.sector_size).to eq(512)
    end
  end

  describe "#udev_id" do
    let(:udev_ids) { ["ata-Micron_1100_SATA_512GB_170115619F17"] }

    before do
      allow(disk).to receive(:udev_ids).and_return(udev_ids)
    end

    it "returns udev path" do
      expect(value.udev_id).to eq(udev_ids)
    end
  end

  describe "#udev_path" do
    let(:udev_paths) { ["pci-0000:00:17.0-ata-3"] }

    before do
      allow(disk).to receive(:udev_paths).and_return(udev_paths)
    end

    it "returns udev path" do
      expect(value.udev_path).to eq(udev_paths)
    end
  end

  describe "#dasd_type" do
    let(:scenario) { "dasd_50GiB" }
    let(:disk) { Y2Storage::Dasd.find_by_name(fake_devicegraph, "/dev/sda") }

    it "returns type" do
      expect(value.dasd_type).to eq("eckd")
    end

    context "when device is not dasd" do
      let(:scenario) { "windows-linux-free-pc" }
      let(:disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }

      it "returns nil" do
        expect(value.dasd_type).to be_nil
      end
    end
  end
end
