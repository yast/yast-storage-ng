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

describe Y2Storage::EncryptionProcesses::SecureKey do
  def zkey_output(file)
    File.read(File.join(DATA_PATH, "zkey", "#{file}.txt"))
  end

  subject(:key) { described_class.new("cr", sector_size: 2048) }

  describe ".for_device" do
    before do
      fake_scenario("several-dasds")

      allow(Yast::Execute).to receive(:locally).with(/zkey/, "list", any_args)
        .and_return(zkey_list)
    end

    let(:manager) { Y2Storage::StorageManager.instance }
    let(:zkey_list) { zkey_output("list-no-dasdc1") }
    let(:blk_device) { manager.staging.find_by_name("/dev/dasdb1") }

    it "returns the secure key for the given device" do
      key = described_class.for_device(blk_device)
      expect(key).to be_for_device(blk_device)
      expect(key.sector_size).to eq(4096)
    end
  end

  describe ".new_from_zkey" do
    let(:zkey_list) { zkey_output("list-no-dasdc1") }

    it "returns a secure key using the values from the string" do
      key = described_class.new_from_zkey(zkey_list)
      expect(key.sector_size).to eq(4096)
    end

    context "when the sector size is not defined" do
      let(:zkey_list) { zkey_output("list-no-sector-size") }
      it "sets the sector size to nil" do
        key = described_class.new_from_zkey(zkey_list)
        expect(key.sector_size).to be_nil
      end
    end
  end

  describe "#generate" do
    it "runs zkey to create the a LUKS2 key with the given name and sector size" do
      expect(Yast::Execute).to receive(:locally).with(
        "/usr/bin/zkey", "generate", "--name", key.name, "--xts", "--keybits", "256",
        "--volume-type", "LUKS2", "--sector-size", key.sector_size.to_s
      )
      key.generate
    end

    context "when sector size is not set" do
      subject(:key) { described_class.new("cr") }

      it "does not specify any sector size value" do
        expect(Yast::Execute).to receive(:locally) do |*args|
          expect(args).to_not include("--sector-size")
        end

        key.generate
      end
    end
  end
end
