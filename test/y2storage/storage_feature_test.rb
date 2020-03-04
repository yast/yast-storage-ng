#!/usr/bin/env rspec
#
# encoding: utf-8

# Copyright (c) [2020] SUSE LLC
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

describe Y2Storage::StorageFeature do
  describe ".all" do
    # This test will fail every time a new feature is added to libstorage-ng,
    # to remind us we should define its yast2-storage-ng counterpart
    it "contains one entry for each feature from libstorage-ng" do
      constants = ::Storage.constants.select { |c| c.to_s.start_with?("UF_") }
      expect(described_class.all.map(&:to_sym)).to contain_exactly(*constants)
    end
  end

  describe "#in_bitfield?" do
    subject(:feature) { described_class.new(id, []) }

    context "when the feature exists in libstorage-ng" do
      let(:id) { :UF_EXT2 }

      it "returns a boolean" do
        expect(feature.in_bitfield?(0)).to eq false
        expect(feature.in_bitfield?(0xFFFFFFFFFFFFFFFF)).to eq true
      end
    end

    context "when the feature does not exist in libstorage-ng" do
      let(:id) { :UF_NONSENSE }

      # This behavior makes easy to detect when a feature is removed from
      # libstorage-ng. If the behavior is changed, make sure to provide another
      # mechanism (and an automated test) to detect the situation
      it "raises an NameError exception" do
        expect { feature.in_bitfield?(0) }.to raise_error NameError
      end
    end
  end
end
