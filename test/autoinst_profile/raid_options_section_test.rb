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

describe Y2Storage::AutoinstProfile::RaidOptionsSection do
  using Y2Storage::Refinements::SizeCasts

  let(:spec) do
    {
      "persistent_superblock" => true,
      "chunk_size"            => "1M",
      "parity_algorithm"      => "left_symmetric",
      "raid_type"             => "raid1",
      "device_order"          => ["/dev/sda1", "/dev/sdb1"],
      "raid_name"             => "/dev/md0"
    }
  end

  describe ".new_from_hashes" do
    subject(:raid_options) { described_class.new_from_hashes(spec) }

    it "initializes persistent_superblock" do
      expect(raid_options.persistent_superblock).to eq(true)
    end

    it "initializes chunk_size" do
      expect(raid_options.chunk_size).to eq("1M")
    end

    it "initializes parity_algorithm" do
      expect(raid_options.parity_algorithm).to eq("left_symmetric")
    end

    it "initializes raid_type" do
      expect(raid_options.raid_type).to eq("raid1")
    end

    it "initializes device_order" do
      expect(raid_options.device_order).to eq(["/dev/sda1", "/dev/sdb1"])
    end

    it "initializes raid_name" do
      expect(raid_options.raid_name).to eq("/dev/md0")
    end

    context "when chunk size is just a number" do
      let(:spec) { { "chunk_size" => "64" } }

      it "sets the chunk_size as KB" do
        expect(raid_options.chunk_size).to eq("64")
      end
    end

    context "when chunk_size is not specified" do
      let(:spec) { {} }

      it "sets the chunk_size to nil" do
        expect(raid_options.chunk_size).to be_nil
      end
    end

    context "when raid_type is not specified" do
      let(:spec) { {} }

      it "sets raid_type to nil" do
        expect(raid_options.raid_type).to be_nil
      end
    end

    context "when device order is not specified" do
      let(:spec) { {} }

      it "sets device order to an empty array" do
        expect(raid_options.device_order).to eq([])
      end
    end
  end

  describe ".new_from_storage" do
    let(:md) do
      instance_double(
        Y2Storage::Md,
        chunk_size: 1.MB,
        md_parity:  Y2Storage::MdParity::LEFT_ASYMMETRIC,
        md_level:   Y2Storage::MdLevel::RAID0,
        name:       "/dev/md0"
      )
    end

    subject(:raid_options) { described_class.new_from_storage(md) }

    it "initializes chunk_size" do
      expect(raid_options.chunk_size).to eq(1.MB)
    end

    it "initializes parity_algorithm" do
      expect(raid_options.parity_algorithm).to eq("left_asymmetric")
    end

    it "initializes raid_type" do
      expect(raid_options.raid_type).to eq("raid0")
    end

    it "initializes device_order"

    it "initializes raid_name" do
      expect(raid_options.raid_name).to eq("/dev/md0")
    end
  end
end
