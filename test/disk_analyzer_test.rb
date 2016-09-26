#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

describe Y2Storage::DiskAnalyzer do
  using Y2Storage::Refinements::SizeCasts

  subject(:analyzer) { described_class.new(fake_devicegraph) }

  before do
    fake_scenario("gpt_and_msdos")
  end

  describe "#mbr_gap" do
    it "returns the gap for every disk" do
      expect(analyzer.mbr_gap.keys).to eq ["/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd", "/dev/sde"]
    end

    it "returns 0 bytes for disks without partition table" do
      expect(analyzer.mbr_gap["/dev/sde"]).to eq 0.KiB
    end

    it "returns 0 bytes for GPT disks without partitions" do
      expect(analyzer.mbr_gap["/dev/sdd"]).to eq 0.KiB
    end

    it "returns 0 bytes for GPT disks with partitions" do
      expect(analyzer.mbr_gap["/dev/sdb"]).to eq 0.KiB
    end

    it "returns 0 bytes for MS-DOS disks without partitions" do
      expect(analyzer.mbr_gap["/dev/sdc"]).to eq 0.KiB
    end

    it "returns the gap for MS-DOS disks with partitions" do
      expect(analyzer.mbr_gap["/dev/sda"]).to eq 1.MiB
    end
  end
end
