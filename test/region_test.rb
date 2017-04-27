#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

describe Y2Storage::Region do
  using Y2Storage::Refinements::SizeCasts

  subject(:region) { Y2Storage::Region.create(100, 1000, 1.KiB) }

  describe "#==" do
    context "if both regions has a different block size" do
      let(:other) { Y2Storage::Region.create(100, 1000, 2.KiB) }

      # To ensure the exception is propagated by the bindings
      it "raises Storage::DifferentBlockSizes" do
        expect { region <=> other }.to raise_error Storage::DifferentBlockSizes
      end
    end

    context "if the right operand is not a region" do
      let(:other) { 2048 }

      it "raises TypeError" do
        expect { region <=> other }.to raise_error TypeError
      end
    end

    context "if both regions are equivalent" do
      let(:other) { Y2Storage::Region.create(100, 1000, 1.KiB) }

      it "returns true" do
        expect(region == other).to eq true
      end
    end

    context "if the start sector is different" do
      let(:other) { Y2Storage::Region.create(101, 1000, 1.KiB) }

      it "returns false" do
        expect(region == other).to eq false
      end
    end

    context "if the length is different" do
      let(:other) { Y2Storage::Region.create(100, 1001, 1.KiB) }

      it "returns false" do
        expect(region == other).to eq false
      end
    end
  end
end
