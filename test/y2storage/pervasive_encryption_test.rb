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

require_relative "spec_helper"
require "y2storage"
require "y2storage/encryption_processes/secure_key"
require "yast2/execute"

describe "pervasive encryption" do
  def zkey_output(file)
    File.read(File.join(DATA_PATH, "zkey", "#{file}.txt"))
  end

  before do
    fake_scenario("several-dasds")

    allow(Yast::Execute).to receive(:locally)
    allow(Yast::Execute).to receive(:locally).with(/zkey/, "list", any_args)
      .and_return zkey_list
  end

  let(:manager) { Y2Storage::StorageManager.instance }
  let(:blk_device) { manager.staging.find_by_name("/dev/dasdc1") }
  let(:pervasive) { Y2Storage::EncryptionMethod::PERVASIVE_LUKS2 }
  let(:zkey_list) { zkey_output("list-dasdc1") }

  describe "Y2Storage::BlkDevice#encrypt" do
    it "creates an encryption device with type LUKS2 and method PERVASIVE_LUKS2" do
      enc = blk_device.encrypt(method: pervasive)
      expect(enc.type.is?(:luks2)).to eq(true)
      expect(enc.method).to eq pervasive
    end

    context "if there is a preexisting secure key for the device" do
      let(:zkey_list) { zkey_output("list-dasdc1") }

      it "enforces the DeviceMapper name specified in the registry of keys" do
        enc = blk_device.encrypt(method: pervasive)
        expect(enc.dm_table_name).to eq "cr_7"
        expect(enc.auto_dm_name?).to eq false
      end
    end

    context "if there is no preexisting secure key for the device" do
      let(:zkey_list) { zkey_output("list-no-dasdc1") }

      it "suggests the standard YaST DeviceMapper name" do
        enc = blk_device.encrypt(method: pervasive)
        expect(enc.dm_table_name).to eq "cr_#{blk_device.basename}"
        expect(enc.auto_dm_name?).to eq true
      end
    end

    context "if the check for existing keys fails" do
      let(:zkey_list) { nil }

      it "suggests the standard YaST DeviceMapper name" do
        enc = blk_device.encrypt(method: pervasive)
        expect(enc.dm_table_name).to eq "cr_#{blk_device.basename}"
        expect(enc.auto_dm_name?).to eq true
      end
    end
  end

  describe "Y2Storage::StorageManager#commit" do
    before do
      allow(manager.storage).to receive(:calculate_actiongraph)
      allow(manager.storage).to receive(:commit)

      allow(Yast::Mode).to receive(:installation).and_return false
      allow(Yast::Stage).to receive(:initial).and_return false
    end

    RSpec.shared_examples "zkey cryptsetup actions" do
      before do
        allow(Yast::Execute).to receive(:locally)
          .with(/zkey/, "cryptsetup", "--volumes", anything, stdout: :capture)
          .and_return zkey_cryptsetup
      end
      # I'm not sure why this default value is needed
      let(:zkey_cryptsetup) { "" }

      context "if the 'zkey cryptsetup' command fails" do
        let(:zkey_cryptsetup) { nil }

        it "anyway sets options for 'cryptsetup luksFormat'" do
          enc = blk_device.encrypt(method: pervasive)
          manager.commit

          expect(enc.format_options).to include("--master-key-file")
        end
      end

      context "if 'zkey cryptsetup' returns several commands" do
        let(:zkey_cryptsetup) do
          "cryptsetup luksFormat --one two --three /dev/whatever\n" \
            "zkey-cryptsetup setvp --volumes /dev/whatever\n" \
            "third command"
        end

        it "ignores arguments from 'zkey' for 'cryptsetup luksFormat'" do
          enc = blk_device.encrypt(method: pervasive)
          manager.commit

          expect(enc.format_options).to_not include("--one two")
        end

        it "executes the post-commit commands providing the password when needed" do
          expect(Yast::Execute).to receive(:locally)
            .with("zkey-cryptsetup", "setvp", any_args, stdin: "12345678", recorder: anything)
          expect(Yast::Execute).to receive(:locally).with("third", "command")

          blk_device.encrypt(method: pervasive, password: "12345678")
          manager.commit
        end

        # We used to memoize the Cheetah recorder in an instance variable, which had nasty
        # consequences when using the userdata mechanism to store and restore the process
        it "does not break the serialization of the encryption process" do
          enc = blk_device.encrypt(method: pervasive)
          manager.commit

          enc_new = manager.staging.find_device(enc.sid)
          # Accessing the encryption process after having called the command
          # "zkey-cryptsetup setvp" resulted in the following NoMethodError:
          # "private method `allocate' called for Yast::Y2Logger:Class"
          expect { enc_new.method }.to_not raise_error
        end
      end
    end

    context "if there is a preexisting secure key for the device" do
      let(:zkey_list) { zkey_output("list-dasdc1") }

      it "does not generate a new secure key" do
        expect(Yast::Execute).to_not receive(:locally)
          .with(/zkey/, "generate", any_args)

        blk_device.encrypt(method: pervasive)
        manager.commit
      end

      include_examples "zkey cryptsetup actions"
    end

    context "if there is no secure key for the device" do
      let(:zkey_list) { zkey_output("list-no-dasdc1") }

      it "tries to generate a new secure key with the appropriate name and arguments" do
        expect(Yast::Execute).to receive(:locally).with(
          /zkey/, "generate", "-V", "--name", "YaST_cr_dasdc1_1", "--xts", "--keybits", "256",
          "--volume-type", "LUKS2", "--sector-size", "4096", "--key-type", anything
        )

        blk_device.encrypt(method: pervasive)
        manager.commit
      end

      include_examples "zkey cryptsetup actions"
    end
  end
end
