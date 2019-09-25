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

describe Y2Storage::EncryptionProcesses::ProtectedSwap do
  subject { described_class.new(method) }

  let(:method) { instance_double(Y2Storage::EncryptionMethod) }

  let(:protected_key_file) { described_class.key_file }

  describe ".available?" do
    before do
      allow(File).to receive(:exist?).with(protected_key_file).and_return(exist_key_file)
    end

    context "when the key file for protected key is found" do
      let(:exist_key_file) { true }

      it "returns true" do
        expect(described_class.available?).to eq(true)
      end
    end

    context "when key file for protected key is not found" do
      let(:exist_key_file) { false }

      it "returns false" do
        expect(described_class.available?).to eq(false)
      end
    end
  end

  describe "#only_for_swap?" do
    it "returns true" do
      expect(described_class.only_for_swap?).to eq(true)
    end
  end

  describe ".used_for?" do
    let(:encryption) do
      instance_double(Y2Storage::Encryption, key_file: key_file, crypt_options: crypt_options)
    end

    let(:key_file) { nil }

    let(:crypt_options) { [] }

    context "when the given encryption device does not contain 'swap' option" do
      let(:crypt_options) { ["something", "else"] }

      it "returns false" do
        expect(described_class.used_for?(encryption)).to eq(false)
      end
    end

    context "when the given encryption device does not use the key file for protected keys" do
      let(:key_file) { "/dev/other" }

      it "returns false" do
        expect(described_class.used_for?(encryption)).to eq(false)
      end
    end

    context "when the given encryption device contains 'swap' option and uses the proper key file" do
      let(:crypt_options) { ["a", "SWAP"] }

      let(:key_file) { protected_key_file }

      it "returns true" do
        expect(described_class.used_for?(encryption)).to eq(true)
      end
    end
  end

  describe ".used_for_crypttab?" do
    let(:entry) do
      instance_double(
        Y2Storage::SimpleEtcCrypttabEntry, password: password, crypt_options: crypt_options
      )
    end

    let(:password) { nil }

    let(:crypt_options) { [] }

    context "when the given crypttab entry does not contain 'swap' option" do
      let(:crypt_options) { ["something", "else"] }

      it "returns false" do
        expect(described_class.used_for_crypttab?(entry)).to eq(false)
      end
    end

    context "when the given crypttab entry does not use the key file for protected keys" do
      let(:password) { "/dev/other" }

      it "returns false" do
        expect(described_class.used_for_crypttab?(entry)).to eq(false)
      end
    end

    context "when the given crypttab entry contains 'swap' option and uses the proper key file" do
      let(:crypt_options) { ["a", "SWAP"] }

      let(:password) { protected_key_file }

      it "returns true" do
        expect(described_class.used_for_crypttab?(entry)).to eq(true)
      end
    end
  end

  describe "#create_device" do
    before do
      fake_scenario("empty_hard_disk_50GiB")
    end

    let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    let(:device) { devicegraph.find_by_name("/dev/sda") }

    let(:dm_name) { "cr_sda" }

    it "returns an encryption device" do
      result = subject.create_device(device, dm_name)

      expect(result.is?(:encryption)).to eq(true)
    end

    it "creates an plain encryption device for the given device" do
      expect(device.encrypted?).to eq(false)

      subject.create_device(device, dm_name)

      expect(device.encrypted?).to eq(true)
      expect(device.encryption.type.is?(:plain)).to eq(true)
    end

    it "sets the key file for protected key" do
      encryption = subject.create_device(device, dm_name)

      expect(encryption.key_file).to eq(protected_key_file)
    end

    it "sets the 'swap' encryption option" do
      encryption = subject.create_device(device, dm_name)

      expect(encryption.crypt_options).to include("swap")
    end

    it "sets the cipher for protected key" do
      encryption = subject.create_device(device, dm_name)

      expect(encryption.crypt_options).to include("cipher=paes-xts-plain64")
    end

    it "sets the key size for protected key" do
      encryption = subject.create_device(device, dm_name)

      expect(encryption.crypt_options).to include("size=1280")
    end
  end
end
