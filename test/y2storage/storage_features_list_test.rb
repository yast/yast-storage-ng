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
require "y2storage/storage_feature"
require "y2storage/storage_features_list"

describe Y2Storage::StorageFeaturesList do
  describe ".new" do
    let(:features) do
      [Y2Storage::StorageFeature.new(:UF_BTRFS, []), Y2Storage::StorageFeature.new(:UF_EXT2, [])]
    end

    it "returns an empty list when called with no arguments" do
      expect(described_class.new).to be_empty
    end

    it "returns a list of features when called with several features" do
      expect(described_class.new(*features)).to contain_exactly(*features)
    end

    it "returns a list of features when called with an array of features" do
      expect(described_class.new(features)).to contain_exactly(*features)
    end
  end

  describe ".from_bitfield" do
    context "if the bit-field is zero" do
      it "returns an empty list" do
        expect(described_class.from_bitfield(0)).to be_empty
      end
    end

    context "with a non-zero bit-field" do
      it "returns the corresponding list of features" do
        bits = Storage::UF_BTRFS | Storage::UF_LVM
        list = described_class.from_bitfield(bits)
        expect(list).to all be_a(Y2Storage::StorageFeature)
        expect(list.map(&:id)).to contain_exactly(:UF_BTRFS, :UF_LVM)

        bits = Storage::UF_EXT2
        list = described_class.from_bitfield(bits)
        expect(list.size).to eq 1
        feature = list.first
        expect(feature).to be_a Y2Storage::StorageFeature
        expect(feature.to_sym).to eq :UF_EXT2
      end
    end
  end

  describe "#pkg_list" do
    subject(:list) { described_class.from_bitfield(bits) }

    context "if several features require the same package" do
      let(:bits) do
        Storage::UF_EXT2 | Storage::UF_LUKS | Storage::UF_EXT3 | Storage::UF_PLAIN_ENCRYPTION
      end

      it "includes the package only once (no duplicates)" do
        expect(list.pkg_list.sort).to eq ["cryptsetup", "device-mapper", "e2fsprogs"]
      end
    end

    context "if some packages are optional" do
      let(:bits) { Storage::UF_NTFS | Storage::UF_EXT3 }

      before do
        Y2Storage::StorageFeature.drop_cache
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
