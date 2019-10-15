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

# For a complete pervasive encryption test, see test/y2storage/pervasive_encryption_test.rb
describe Y2Storage::EncryptionProcesses::Pervasive do
  subject(:process) { described_class.new(method) }

  let(:method) { double }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda") }
  let(:dm_name) { "cr_sda" }
  let(:zkey_cryptsetup) do
    "cryptsetup luksFormat --foo bar --dummy /dev/dasdc1\n" \
      "zkey-cryptsetup setvp --volumes /dev/dasdc1\n" \
      "third-command"
  end

  let(:secure_key) { nil }

  before do
    devicegraph_stub("empty_hard_disk_50GiB.yml")
    allow(Yast::Execute).to receive(:locally)
      .with(/zkey/, "cryptsetup", "--volumes", "/dev/dasdc1", anything)
      .and_return(zkey_cryptsetup)
    allow(Y2Storage::EncryptionProcesses::SecureKey).to receive(:for_device)
      .and_return(secure_key)
  end

  describe "#create_device" do
    it "returns an encryption device" do
      encryption = process.create_device(blk_device, dm_name)
      expect(encryption.is?(:encryption)).to eq(true)
      expect(encryption.dm_table_name).to eq("cr_sda")
    end

    it "creates an luks2 encryption device for given block device" do
      encryption = process.create_device(blk_device, dm_name)
      expect(encryption.type).to eq(Y2Storage::EncryptionType::LUKS2)
    end

    context "when a secure key for the device was found" do
      let(:secure_key) do
        instance_double(Y2Storage::EncryptionProcesses::SecureKey, dm_name: "cr_custom")
      end

      it "uses the dm name from the key" do
        encryption = process.create_device(blk_device, dm_name)
        expect(encryption.dm_table_name).to eq("cr_custom")
      end
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

  describe "#pre_commit" do
    let(:encryption) { subject.create_device(blk_device, dm_name) }

    let(:secure_key) { nil }

    let(:generated_key) do
      instance_double(Y2Storage::EncryptionProcesses::SecureKey,
        plain_name: "/dev/dasdc1", dm_name: "cr_1", name: "secure_xtskey1")
    end

    before do
      allow(Y2Storage::EncryptionProcesses::SecureKey).to receive(:generate)
        .and_return(generated_key)
    end

    it "generates a new secure key for the device" do
      expect(Y2Storage::EncryptionProcesses::SecureKey).to receive(:generate)
        .with("YaST_cr_sda", volumes: [encryption]).and_return(generated_key)
      subject.pre_commit(encryption)
    end

    context "when a secure key for the device was found" do
      let(:secure_key) { generated_key }

      it "does not generate a new secure key" do
        expect(Y2Storage::EncryptionProcesses::SecureKey).to_not receive(:generate)
        subject.pre_commit(encryption)
      end
    end

    it "sets LUKS format options" do
      subject.pre_commit(encryption)
      expect(encryption.format_options).to include("--foo bar --dummy --pbkdf pbkdf2")
    end
  end

  describe "#post_commit" do
    let(:encryption) { subject.create_device(blk_device, dm_name) }

    let(:secure_key) do
      instance_double(Y2Storage::EncryptionProcesses::SecureKey,
        plain_name: "/dev/dasdc1", dm_name: "cr_1", name: "secure_xtskey1")
    end

    before do
      subject.pre_commit(encryption)
    end

    it "executes commands reported by zkey cryptsetup skipping the first one" do
      expect(Yast::Execute).to receive(:locally).with(/zkey-cryptsetup/, any_args)
      expect(Yast::Execute).to receive(:locally).with("third-command")
      subject.post_commit(encryption)
    end

    it "adds the --key-file option to the setvp command" do
      allow(Yast::Execute).to receive(:locally)
      expect(Yast::Execute).to receive(:locally)
        .with(/zkey-cryptsetup/, "setvp", "--volumes", "/dev/dasdc1", "--key-file", "-", any_args)
      subject.post_commit(encryption)
    end
  end
end
