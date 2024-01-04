#!/usr/bin/env rspec
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

require_relative "../../test_helper"
require_relative "shared_examples"

require "y2partitioner/widgets/columns/pe_size"

describe Y2Partitioner::Widgets::Columns::PeSize do
  using Y2Storage::Refinements::SizeCasts
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:device) { double(Y2Storage::Device) }

  describe "#value_for" do
    context "when the device responds to #extent_size" do
      before do
        allow(device).to receive(:respond_to?).with(:extent_size).and_return(true)
        allow(device).to receive(:extent_size).and_return(Y2Storage::DiskSize.new(64.KiB))
      end

      it "returns its human string representation" do
        expect(subject.value_for(device)).to eq("64.00 KiB")
      end
    end

    context "when the device does not respond to #extent_size" do
      before do
        allow(device).to receive(:respond_to?).with(:extent_size).and_return(false)
      end

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end
  end
end
