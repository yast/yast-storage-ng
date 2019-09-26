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

describe Y2Storage::EncryptionProcesses::Luks1 do
  subject(:process) { described_class.new(method) }
  let(:method) { double }

  describe ".used_for?" do
    let(:encryption) { double(Y2Storage::Encryption, type: type) }

    context "when the encryption type is LUKS1'" do
      let(:type) { Y2Storage::EncryptionType::LUKS1 }

      it "returns true" do
        expect(described_class.used_for?(encryption)).to eq(true)
      end
    end

    context "when the encryption type is not LUKS1'" do
      let(:type) { Y2Storage::EncryptionType::PLAIN }

      it "returns false" do
        expect(described_class.used_for?(encryption)).to eq(false)
      end
    end
  end

  describe ".only_for_swap?" do
    it "returns false" do
      expect(described_class.only_for_swap?).to eq(false)
    end
  end

  describe "#create_device" do
    let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
    let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda") }
    let(:dm_name) { "cr_sda" }

    before do
      devicegraph_stub("empty_hard_disk_50GiB.yml")
    end

    it "returns an encryption device" do
      encryption = process.create_device(blk_device, dm_name)

      expect(encryption.is?(:encryption)).to eq(true)
    end

    it "creates an luks1 encryption device for given block device" do
      expect(blk_device).to receive(:create_encryption)
        .with(anything, Y2Storage::EncryptionType::LUKS1)
        .and_call_original

      process.create_device(blk_device, dm_name)
    end

    it "does not set any specific encryption option" do
      encryption = subject.create_device(blk_device, dm_name)

      expect(encryption.crypt_options).to be_empty
    end

    it "does not set any specific open option" do
      encryption = subject.create_device(blk_device, dm_name)

      expect(encryption.open_options).to be_empty
    end
  end
end
