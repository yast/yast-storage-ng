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

require_relative "spec_helper"
require "y2storage"
require "y2storage/md_level"
require "y2storage/md_parity"

describe Y2Storage::Md do
  using Y2Storage::Refinements::SizeCasts

  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "md2-devicegraph.xml" }
  let(:md_name) { "/dev/md0" }
  subject(:md) { Y2Storage::Md.find_by_name(fake_devicegraph, md_name) }

  describe "#devices" do

    it "returns the array of BlkDevices use" do
      # TODO: check the complete return value
      expect(md.devices.size).to eq 2
    end

  end

  describe "#numeric?" do

    it "returns true for /dev/md0" do
      expect(md.numeric?).to eq true
    end

  end

  describe "#number" do

    it "returns 0 for /dev/md0" do
      expect(md.number).to eq 0
    end

  end

  describe "#md_level" do

    it "returns the MD RAID level" do
      expect(md.md_level).to eq Y2Storage::MdLevel::RAID0
    end
  end

  describe "#md_level=" do

    it "set the MD RAID level" do
      md.md_level = Y2Storage::MdLevel::RAID1
      expect(md.md_level).to eq Y2Storage::MdLevel::RAID1
    end

  end

  describe "#md_parity" do

    it "returns the MD RAID parity" do
      expect(md.md_parity).to eq Y2Storage::MdParity::DEFAULT
    end

  end

  describe "#chunk_size" do

    it "returns the MD RAID chunk size" do
      expect(md.chunk_size).to eq 512.KiB
    end
  end

  describe "#chunk_size=" do

    it "sets the MD RAID chunk size" do
      md.chunk_size = 256.KiB
      expect(md.chunk_size).to eq 256.KiB
    end

  end

  describe "#uuid" do

    it "returns the MD RAID UUID" do
      expect(md.uuid).to eq "d11cbd17:b4fa9ccd:bb7b9bab:557d863c"
    end

  end

  describe "#superblock_version" do

    it "returns the MD RAID superblock version as a string" do
      expect(md.superblock_version).to eq "1.0"
    end

  end

  describe "#in_etc_mdadm" do

    it "returns false since the MD RAID is not in /etc/mdadm.conf" do
      expect(md.in_etc_mdadm?).to eq false
    end

  end

  describe "#inspect" do

    it "inspects a MD object" do
      expect(md.inspect).to eq "<Md /dev/md0 32767 MiB (32.00 GiB) raid0>"
    end

  end

  describe "#is?" do

    it "returns true for values whose symbol is :md" do
      expect(md.is?(:md)).to eq true
      expect(md.is?("md")).to eq true
    end

    it "returns false for a different string like \"Md\"" do
      expect(md.is?("Md")).to eq false
    end

    it "returns false for different device names like :partition or :filesystem" do
      expect(md.is?(:partition)).to eq false
      expect(md.is?(:filesystem)).to eq false
    end

  end

  describe "#find_free_numeric_name" do

    it "returns the next free number MD RAID name" do
      expect(Y2Storage::Md.find_free_numeric_name(fake_devicegraph)).to eq "/dev/md3"
    end

  end

end
