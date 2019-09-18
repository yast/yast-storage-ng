#!/usr/bin/env rspec
# Copyright (c) [2018] SUSE LLC
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
require "y2storage/encryption_processes/secure_key"
require "yast2/execute"

describe "the pervasive prototype" do
  def zkey_output(file)
    File.read(File.join(DATA_PATH, "zkey", "#{file}.txt"))
  end

  def lszcrypt_output(file)
    File.read(File.join(DATA_PATH, "lszcrypt", "#{file}.txt"))
  end

  before do
    fake_scenario("several-dasds")

    allow(manager.storage).to receive(:calculate_actiongraph)
    allow(manager.storage).to receive(:commit)

    allow(Yast::Mode).to receive(:installation).and_return false
    allow(Yast::Stage).to receive(:initial).and_return false

    allow(Yast::Execute).to receive(:locally)

    allow(Yast::Execute).to receive(:locally).with(/zkey/, "list", "--volumes", any_args)
      .and_return zkey_list_volume

    allow(Yast::Execute).to receive(:locally)
      .with("zkey", "cryptsetup", "--volumes", anything, stdout: :capture)
      .and_return(
        "cryptsetup luksFormat --one two --three /dev/whatever\n" \
        "zkey-cryptsetup setvp --volumes /dev/whatever\n" \
        "third command"
      )

    allow(Yast::Execute).to receive(:locally!).with("/sbin/lszcrypt", "--verbose", stdout: :capture)
      .and_return lszcrypt
  end

  let(:manager) { Y2Storage::StorageManager.instance }
  let(:blk_device) { manager.staging.find_by_name("/dev/dasdc1") }
  let(:pervasive) { Y2Storage::EncryptionMethod::PERVASIVE_LUKS2 }
  let(:lszcrypt) { "" }

  RSpec.shared_examples "zkey cryptsetup actions" do
    it "generates arguments for 'cryptsetup luksFormat'" do
      enc = blk_device.encrypt(method: pervasive)
      manager.commit

      expect(enc.format_options).to eq "--one two --three --pbkdf pbkdf2"
    end

    it "executes the post-commit commands" do
      expect(Yast::Execute).to receive(:locally)
        .with("zkey-cryptsetup", "setvp", any_args, stdin: "12345678", recorder: anything)
      expect(Yast::Execute).to receive(:locally).with("third", "command")

      blk_device.encrypt(method: pervasive, password: "12345678")
      manager.commit
    end
  end

  context "if there is a secret key for the device" do
    let(:zkey_list_volume) { zkey_output("list-volume") }

    it "uses the DeviceMapper name specified in the registry of keys" do
      enc = blk_device.encrypt(method: pervasive)
      expect(enc.dm_table_name).to eq "cr_7"
    end

    include_examples "zkey cryptsetup actions"
  end

  context "if there is no secret key for the device" do
    let(:zkey_list_volume) { "" }

    before do
      # Mocking the check for existing names
      allow(Yast::Execute).to receive(:locally).with(/zkey/, "list", stdout: :capture)
        .and_return zkey_output("list")
    end

    it "uses the standard YaST DeviceMapper name" do
      enc = blk_device.encrypt(method: pervasive)
      expect(enc.dm_table_name).to eq "cr_#{blk_device.basename}"
    end

    it "tries to generate a new secret key during commit" do
      expect(Yast::Execute).to receive(:locally).with(
        "zkey", "generate", "--name", "YaST_cr_dasdc1", "--xts", "--keybits", "256",
        "--volume-type", "LUKS2", "--sector-size", "4096", "--volumes", "/dev/dasdc1:cr_dasdc1"
      )

      blk_device.encrypt(method: pervasive)
      manager.commit
    end

    include_examples "zkey cryptsetup actions"
  end

  describe "#available?" do
    let(:zkey_list_volume) { "" }

    context "if secure key is available" do
      let(:lszcrypt) { lszcrypt_output("ok") }

      it "returns true" do
        enc = blk_device.encrypt(method: pervasive)
        expect(enc.method.available?).to be true
      end
    end

    context "if no secure key devices are available" do
      let(:lszcrypt) { lszcrypt_output("no_devs") }

      it "returns false" do
        enc = blk_device.encrypt(method: pervasive)
        expect(enc.method.available?).to be false
      end
    end

    context "if secure key is not supported" do
      let(:lszcrypt) { nil }

      it "returns false" do
        enc = blk_device.encrypt(method: pervasive)
        expect(enc.method.available?).to be false
      end
    end

    context "if lszcrypt tool is not available" do
      let(:lszcrypt) { nil }

      before do
        allow(Yast::Execute).to receive(:locally!).with("/sbin/lszcrypt", "--verbose", stdout: :capture)
        .and_raise Cheetah::ExecutionFailed
      end

      it "returns false" do
        enc = blk_device.encrypt(method: pervasive)
        expect(enc.method.available?).to be false
      end
    end
  end
end
