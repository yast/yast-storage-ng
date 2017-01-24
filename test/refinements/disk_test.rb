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

describe "Refinements::Disk" do
  using Y2Storage::Refinements::Disk
  using Y2Storage::Refinements::SizeCasts

  before do
    fake_scenario("gpt_msdos_and_empty")
  end

  describe "#free_spaces" do
    subject(:disk) { Storage::Disk.find_by_name(fake_devicegraph, disk_name) }

    context "in a disk with no partition table, no PV and no filesystem" do
      let(:disk_name) { "/dev/sde" }

      it "returns an array with just one element" do
        expect(disk.free_spaces.size).to eq 1
      end

      it "considers the whole disk to be free space" do
        space = disk.free_spaces.first
        expect(space.region.start).to eq 0
        expect(space.disk_size.to_i).to eq disk.size
      end
    end

    context "in a directly formated disk (filesystem but no partition table)" do
      let(:disk_name) { "/dev/sdf" }

      it "returns an empty array" do
        expect(disk.free_spaces).to be_empty
      end
    end

    context "in a disk directly used as LVM PV (no partition table)" do
      let(:disk_name) { "/dev/sdg" }

      it "returns an empty array" do
        expect(disk.free_spaces).to be_empty
      end
    end

    context "in a disk with an empty GPT partition table" do
      let(:disk_name) { "/dev/sdd" }

      let(:ptable_size) { 1.MiB }
      # The final 16.5 KiB are reserved by GPT
      let(:gpt_final_space) { 16.5.KiB }

      it "returns an array with just one element" do
        expect(disk.free_spaces.size).to eq 1
      end

      it "starts counting right after the partition table" do
        region = disk.free_spaces.first.region
        expect(region.start).to eq(ptable_size.to_i / region.block_size)
      end

      it "discards the space reserved by GPT at the end of the disk" do
        region = disk.free_spaces.first.region
        discarded = disk.region.end - region.end
        expect(discarded * region.block_size).to eq gpt_final_space.to_i
      end
    end

    context "in a disk with an empty MBR partition table" do
      let(:disk_name) { "/dev/sdb" }
      let(:ptable_size) { 1.MiB }

      it "returns an array with just one element" do
        expect(disk.free_spaces.size).to eq 1
      end

      it "starts counting right after the partition table" do
        region = disk.free_spaces.first.region
        expect(region.start).to eq(ptable_size.to_i / region.block_size)
      end

      it "counts after the end of the disk" do
        region = disk.free_spaces.first.region
        expect(region.end).to eq disk.region.end
      end
    end

    context "in a disk with a fully used partition table" do
      let(:disk_name) { "/dev/sda" }

      it "returns an empty array" do
        expect(disk.free_spaces).to be_empty
      end
    end

    context "in a disk with some partitions and some free slots" do
      let(:disk_name) { "/dev/sdc" }

      let(:ptable_size) { 1.MiB }
      let(:gpt_final_space) { 16.5.KiB }

      it "returns one element for each slot" do
        expect(disk.free_spaces.size).to eq 2
      end

      it "calculates properly the size of each free slot" do
        sorted = disk.free_spaces.sort_by { |s| s.region.start }

        expect(sorted.first.disk_size).to eq 500.GiB
        last_size = 1.TiB - 500.GiB - 60.GiB - ptable_size - gpt_final_space
        expect(sorted.last.disk_size).to eq(last_size)
      end
    end
  end
end
