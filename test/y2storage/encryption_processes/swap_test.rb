#!/usr/bin/env rspec
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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::EncryptionProcesses::Swap do
  subject(:process) { described_class.new(method) }
  let(:method) { double }

  describe ".used_for?" do
    let(:encryption) { double(Y2Storage::Encryption, crypt_options: crypt_options) }

    context "when crypt_options contains 'swap'" do
      let(:crypt_options) { ["a", "SWAP"] }

      it "returns true" do
        expect(described_class.used_for?(encryption)).to eq(true)
      end
    end

    context "when crypt_options does not contain 'swap'" do
      let(:crypt_options) { ["something", "else"] }

      it "returns false" do
        expect(described_class.used_for?(encryption)).to eq(false)
      end
    end
  end

  describe ".only_for_swap?" do
    it "returns true" do
      expect(described_class.only_for_swap?).to eq(true)
    end
  end

  describe "#create_device" do
    let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
    let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda") }
    let(:dm_name) { "cr_sda" }

    let(:key_file) { "/test/key/file" }
    let(:crypt_options) { ["test", "crypt", "options"] }

    before do
      devicegraph_stub("empty_hard_disk_50GiB.yml")
      allow(process).to receive(:key_file).and_return(key_file)
      allow(process).to receive(:crypt_options).and_return(crypt_options)
    end

    it "creates an plain encryption device for given block device" do
      expect(blk_device).to receive(:create_encryption)
        .with(anything, Y2Storage::EncryptionType::PLAIN)
        .and_call_original

      process.create_device(blk_device, dm_name)
    end

    it "sets the encryption key file" do
      encryption = process.create_device(blk_device, dm_name)

      expect(encryption.key_file).to eq(key_file)
    end

    it "sets the crypt options" do
      encryption = process.create_device(blk_device, dm_name)

      expect(encryption.crypt_options).to eq(crypt_options)
    end

    it "returns an encryption device" do
      encryption = process.create_device(blk_device, dm_name)

      expect(encryption).to be_kind_of(Y2Storage::Encryption)
    end
  end
end
