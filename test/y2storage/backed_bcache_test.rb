#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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

describe Y2Storage::BackedBcache do
  using Y2Storage::Refinements::SizeCasts

  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "bcache1.xml" }

  let(:bcache_name) { "/dev/bcache0" }

  subject(:bcache) { Y2Storage::Bcache.find_by_name(fake_devicegraph, bcache_name) }

  describe "#backing_device" do
    it "returns a BlkDevice" do
      expect(subject.backing_device).to be_a Y2Storage::BlkDevice
    end

    it "returns the backing device for the Backed Bcache" do
      expect(subject.backing_device.basename).to eq "vdc"
    end
  end

  describe "#bcache_cset" do
    it "returns the associated caching set" do
      expect(subject.bcache_cset).to be_a Y2Storage::BcacheCset
      expect(subject.bcache_cset.blk_devices.map(&:basename)).to contain_exactly("vdb")
    end
  end

  describe "#attach_bcache_cset" do
    it "attaches a set to the Backed Bcache device" do
      new_bcache = described_class.create(fake_devicegraph, "/dev/bcache99")
      cset = fake_devicegraph.bcache_csets.first

      expect(new_bcache.bcache_cset).to eq nil
      new_bcache.attach_bcache_cset(cset)
      expect(new_bcache.bcache_cset).to eq cset
    end
  end

  describe "#is?" do
    it "returns true for values whose symbol is :backed_bcache" do
      expect(bcache.is?(:backed_bcache)).to eq true
      expect(bcache.is?("backed_bcache")).to eq true
    end

    it "returns false for a different string like \"Disk\"" do
      expect(bcache.is?("Disk")).to eq false
    end

    it "returns false for different device names like :partition or :filesystem" do
      expect(bcache.is?(:partition)).to eq false
      expect(bcache.is?(:filesystem)).to eq false
    end

    it "returns true for a list of names containing :backed_bcache" do
      expect(bcache.is?(:backed_bcache, :partition)).to eq true
    end

    it "returns false for a list of names not containing :backed_bcache" do
      expect(bcache.is?(:filesystem, :partition)).to eq false
    end
  end

  describe "#inspect" do
    context "when the Backed Bcache has an associated caching set" do
      let(:bcache_name) { "/dev/bcache0" }

      it "includes the caching set info" do
        expect(subject.inspect).to include("BcacheCset")
      end
    end

    context "when the Backed Bcache has no associated caching set" do
      before do
        vdd = fake_devicegraph.find_by_name("/dev/vdd")
        vdd.remove_descendants
        vdd.create_bcache(bcache_name)
      end

      let(:bcache_name) { "/dev/bcache99" }

      it "does not include the caching set info" do
        expect(subject.inspect).to_not include("BcacheCset")
        expect(subject.inspect).to include("without caching set")
      end
    end
  end

  describe ".all" do
    it "returns a list of Y2Storage::BackedBcache objects" do
      bcaches = Y2Storage::BackedBcache.all(fake_devicegraph)
      expect(bcaches).to be_an Array
      expect(bcaches).to all(be_a(Y2Storage::BackedBcache))
    end

    it "includes all Backed Bcaches in the devicegraph and nothing else" do
      bcaches = Y2Storage::BackedBcache.all(fake_devicegraph)
      expect(bcaches.map(&:basename)).to contain_exactly(
        "bcache0", "bcache1", "bcache2"
      )
    end
  end
end
