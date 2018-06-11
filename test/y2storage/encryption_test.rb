#!/usr/bin/env rspec
# encoding: utf-8

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
require "y2storage/encryption"

describe Y2Storage::Encryption do
  before do
    fake_scenario(scenario)

    allow(Storage).to receive(:read_simple_etc_crypttab).and_return(storage_entries)
  end

  let(:scenario) { "gpt_encryption" }

  let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

  let(:fstab_entries) do
    [
      crypttab_entry("luks1", device_name, "password", [])
    ]
  end

  let(:storage_entries) { fstab_entries.map(&:to_storage_value) }

  describe ".use_crypttab_names" do
    let(:device) { devicegraph.find_by_name(device_name) }

    context "when a device indicated in a crypttab entry is an encrypted device" do
      let(:device_name) { "/dev/sda4" }

      it "updates the encryption name of that device using the crypttab value" do
        expect(device.encryption.name).to_not eq("/dev/mapper/luks1")

        described_class.use_crypttab_names(devicegraph, "path_to_crypttab")

        expect(device.encryption.name).to eq("/dev/mapper/luks1")
        expect(device.encryption.dm_table_name).to eq("luks1")
      end
    end

    context "when a device indicated in a crypttab entry is not an encrypted device" do
      let(:device_name) { "/dev/sda1" }

      it "does not modify the device" do
        device_before = device.dup

        described_class.use_crypttab_names(devicegraph, "path_to_crypttab")

        expect(device).to eq(device_before)
      end
    end

    context "when a device indicated in a crypttab entry is not found" do
      let(:device_name) { "/dev/sdb1" }

      it "does not fail" do
        expect { described_class.use_crypttab_names(devicegraph, "path_to_crypttab") }
          .to_not raise_error
      end
    end

    context "when an encrypted device is not indicated in any crypttab entry" do
      let(:device_name) { "/dev/sda4" }

      it "does not update the encryption name of that device" do
        device = devicegraph.find_by_name("/dev/sda5")
        encryption_before = device.encryption.dup

        described_class.use_crypttab_names(devicegraph, "path_to_crypttab")

        expect(device.encryption).to eq(encryption_before)
      end
    end
  end
end
