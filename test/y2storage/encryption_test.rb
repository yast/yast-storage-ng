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
require "y2storage"

describe Y2Storage::Encryption do
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
      let(:scenario) { "trivial_lvm_and_other_partitions" }
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
end
