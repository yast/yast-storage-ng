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
  end

  let(:scenario) { "gpt_encryption" }

  let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

  describe ".save_crypttab_names" do
    before do
      allow(Storage).to receive(:read_simple_etc_crypttab).and_return(storage_entries)
    end

    let(:device) { devicegraph.find_by_name(device_name) }

    let(:crypttab_entries) do
      [
        crypttab_entry("luks1", device_name, "password", [])
      ]
    end

    let(:device_name) { "/dev/sda1" }

    let(:storage_entries) { crypttab_entries.map(&:to_storage_value) }

    context "when a path to a crypttab file is given" do
      it "tries to read the crypttab file" do
        expect(Y2Storage::Crypttab).to receive(:new).and_call_original

        described_class.save_crypttab_names(devicegraph, "/etc/crypttab")
      end
    end

    context "when a crypttab object is given" do
      it "uses the crypttab object and does not try to read a new one" do
        crypttab = Y2Storage::Crypttab.new

        expect(Y2Storage::Crypttab).to_not receive(:new)

        described_class.save_crypttab_names(devicegraph, crypttab)
      end
    end

    context "when the device indicated in a crypttab entry is currently encrypted" do
      let(:device_name) { "/dev/sda4" }

      it "saves the crypttab name on the encryption device" do
        expect(device.encryption.crypttab_name).to be_nil

        described_class.save_crypttab_names(devicegraph, "path_to_crypttab")

        expect(device.encryption.crypttab_name).to eq("luks1")
      end
    end

    context "when the device indicated in a crypttab entry is not currently encrypted" do
      let(:device_name) { "/dev/sda1" }

      it "does not fail" do
        expect { described_class.save_crypttab_names(devicegraph, "path_to_crypttab") }
          .to_not raise_error
      end
    end

    context "when the device indicated in a crypttab entry is not found" do
      let(:device_name) { "/dev/sdb1" }

      it "does not fail" do
        expect { described_class.save_crypttab_names(devicegraph, "path_to_crypttab") }
          .to_not raise_error
      end
    end

    context "when an encrypted device is not indicated in any crypttab entry" do
      let(:device_name) { "/dev/sda4" }

      it "does not modify the crypttab name of that encryption device" do
        device = devicegraph.find_by_name("/dev/sda5")

        described_class.save_crypttab_names(devicegraph, "path_to_crypttab")

        expect(device.encryption.crypttab_name).to be_nil
      end
    end
  end

  describe ".dm_name_for" do
    before { fake_scenario(scenario) }

    let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    context "when generating a name for a partition" do
      let(:blk_device) { devicegraph.find_by_name("/dev/sda2") }

      context "if some udev id is known for the partition" do
        # Use the XML format, which includes support for ids
        let(:scenario) { "encrypted_partition.xml" }

        it "generates a name based on the partition udev id" do
          result = described_class.dm_name_for(blk_device)
          expect(result).to match(/^cr_ata-VBOX_HARDDISK_VB777f5d67-56603f01-part2/)
        end
      end

      context "if no udev id is recognized for the partition" do
        let(:scenario) { "trivial_lvm_and_other_partitions" }

        it "generates a name based on the partition name" do
          result = described_class.dm_name_for(blk_device)
          expect(result).to match(/^cr_sda2/)
        end
      end
    end

    context "when generating a name for a logical volume" do
      let(:scenario) { "trivial_lvm_and_other_partitions" }
      let(:blk_device) { devicegraph.find_by_name("/dev/vg0/lv1") }

      it "generates a name based on the volume DeviceMapper name" do
        result = described_class.dm_name_for(blk_device)
        expect(result).to match(/^cr_vg0-lv1/)
      end
    end

    context "when generating a name for a whole disk" do
      let(:blk_device) { devicegraph.find_by_name("/dev/sda") }

      context "if some udev id is known for the disk" do
        # Use the XML format, which includes support for ids
        let(:scenario) { "encrypted_partition.xml" }

        it "generates a name based on the disk udev id" do
          result = described_class.dm_name_for(blk_device)
          expect(result).to match(/^cr_ata-VBOX_HARDDISK_VB777f5d67-56603f01/)
        end
      end

      context "if no udev id is recognized for the disk" do
        let(:scenario) { "trivial_lvm_and_other_partitions" }

        it "generates a name based on the disk name" do
          result = described_class.dm_name_for(blk_device)
          expect(result).to match(/^cr_sda/)
        end
      end
    end

    context "when the generated name is already taken" do
      let(:blk_device) { devicegraph.find_by_name("/dev/sda2") }

      context "if some udev id is known for the partition" do
        # Use the XML format, which includes support for ids
        let(:scenario) { "encrypted_partition.xml" }

        it "generates a name based on the partition udev id" do
          result = described_class.dm_name_for(blk_device)
          expect(result).to match(/^cr_ata-VBOX_HARDDISK_VB777f5d67-56603f01-part2/)
        end
      end

      context "if no udev id is recognized for the partition" do
        let(:scenario) { "trivial_lvm_and_other_partitions" }

        it "generates a name based on the partition name" do
          result = described_class.dm_name_for(blk_device)
          expect(result).to match(/^cr_sda2/)
        end
      end
    end

    context "when the candidate name is already taken" do
      let(:scenario) { "trivial_lvm_and_other_partitions" }
      let(:sda2) { devicegraph.find_by_name("/dev/sda2") }
      let(:sda3) { devicegraph.find_by_name("/dev/sda3") }
      let(:lv1)  { devicegraph.find_by_name("/dev/vg0/lv1") }

      before do
        # Ensure the first option for the name is already taken
        enc_name = Y2Storage::Encryption.dm_name_for(sda2)
        sda3.encryption.dm_table_name = enc_name
      end

      it "adds a number-based suffix" do
        result = described_class.dm_name_for(sda2)
        expect(result).to match(/^cr_sda2_2/)
      end

      context "and the version with suffix is also taken" do
        before do
          # Ensure the second option is taken as well
          lv1.dm_table_name = Y2Storage::Encryption.dm_name_for(sda2)
        end

        it "increases the number in the suffix as much as needed" do
          result = described_class.dm_name_for(sda2)
          expect(result).to match(/^cr_sda2_3/)
        end
      end
    end
  end

  describe ".match_crypttab_spec?" do
    subject { devicegraph.find_by_name(dev_name) }

    let(:scenario) { "encrypted_partition.xml" }

    let(:dev_name) { "/dev/mapper/cr_sda1" }

    it "returns true for the kernel name of the underlying device" do
      expect(subject.match_crypttab_spec?("/dev/sda1")).to eq(true)
    end

    it "returns true for any udev name of the underlying device" do
      subject.blk_device.udev_full_all.each do |name|
        expect(subject.match_crypttab_spec?(name)).to eq(true)
      end
    end

    it "returns false for the kernel name of the encryption device" do
      expect(subject.match_crypttab_spec?("/dev/mapper/cr_sda1")).to eq(false)
    end

    it "returns false for any udev name of the encryption device" do
      subject.udev_full_all.each do |name|
        expect(subject.match_crypttab_spec?(name)).to eq(false)
      end
    end

    it "returns false for other kernel name" do
      expect(subject.match_crypttab_spec?("/dev/sda2")).to eq(false)
    end

    it "returns false for other udev name" do
      expect(subject.match_crypttab_spec?("/dev/disks/by-uuid/111-2222-3333")).to eq(false)
    end
  end
end
