#!/usr/bin/env rspec
#
# encoding: utf-8

# Copyright (c) [2017,2019-2020] SUSE LLC
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
require "y2storage/storage_features_list"

describe Y2Storage::StorageFeaturesList do
  describe ".new" do
    context "if no bit-field is specified" do
      it "returns all possible features" do
        expect(described_class.new).to contain_exactly(*Y2Storage::StorageFeature.all)
      end
    end

    context "if the bit-field is zero" do
      let(:bits) { 0 }

      it "returns an empty list" do
        expect(described_class.new(bits)).to be_empty
      end

      # The combination of this test and the corresponding unit test for
      # StorageFeature#in_bitfield? ensures yast-storage-ng does not contain any
      # feature that is not defined in libstorage-ng (a NameError exception
      # would be raised).
      it "calls #in_bitfield? for all registered features" do
        Y2Storage::StorageFeature.all do |feature|
          expect(feature).to receive(:in_bitfield?).with(bits).and_call_original
        end

        described_class.new(bits)
      end
    end

    context "with a non-zero bit-field" do
      let(:bits) { Storage::UF_BTRFS | Storage::UF_LVM }

      it "returns the corresponding list of features" do
        expect(described_class.new(bits).map(&:id)).to contain_exactly(:UF_BTRFS, :UF_LVM)
      end

      # See note above about the importance of this test
      it "calls #in_bitfield? for all registered features" do
        Y2Storage::StorageFeature.all do |feature|
          expect(feature).to receive(:in_bitfield?).with(bits).and_call_original
        end

        described_class.new(bits)
      end
    end
  end

  describe "#pkg_list" do
    subject(:list) { described_class.new(bits) }

    context "if several features require the same package" do
      let(:bits) do
        Storage::UF_EXT2 | Storage::UF_LUKS | Storage::UF_EXT3 | Storage::UF_PLAIN_ENCRYPTION
      end

      it "includes the package only once (no duplicates)" do
        expect(list.pkg_list.sort).to eq ["cryptsetup", "e2fsprogs"]
      end
    end

    context "if some packages are optional" do
      let(:bits) { Storage::UF_NTFS | Storage::UF_EXT3 }

      before do
        allow(Yast::Package).to receive(:Available).and_return false
        allow(Yast::Package).to receive(:Available).with("ntfsprogs").and_return true
      end

      it "includes the non-optional packages even if they are not available" do
        expect(list.pkg_list).to include "e2fsprogs"
      end

      it "includes the optional packages that are available" do
        expect(list.pkg_list).to include "ntfsprogs"
      end

      it "does not include the optional packages that are not available" do
        expect(list.pkg_list).to_not include "ntfs-3g"
      end
    end

    context "for a list created with a zero bit-field" do
      let(:bits) { 0 }

      it "returns an empty array" do
        expect(list.pkg_list).to eq []
      end
    end
  end
end
