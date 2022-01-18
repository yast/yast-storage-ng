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
require_relative "./shared_examples"

require "y2partitioner/widgets/columns/format"

describe Y2Partitioner::Widgets::Columns::Format do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "mixed_disks" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, "/dev/sda") }

  before do
    devicegraph_stub(scenario)
  end

  describe "#value_for" do
    context "when the device responds to #to_be_formatted?" do
      before do
        allow(device).to receive(:respond_to?).and_call_original
        allow(device).to receive(:respond_to?).with(:to_be_formatted?).and_return(true)
        allow(device).to receive(:to_be_formatted?).and_return(to_be_formatted)
      end

      context "and it is going to be formmated" do
        let(:to_be_formatted) { true }

        it "returns the format flag" do
          expect(subject.value_for(device)).to_not be_empty
        end
      end

      context "but it won't be formmated" do
        let(:to_be_formatted) { false }

        it "returns an empty string" do
          expect(subject.value_for(device)).to eq("")
        end
      end
    end

    context "when the device does not respond to #to_be_formatted?" do
      before do
        allow(device).to receive(:respond_to?).with(:to_be_formatted?).and_return(false)
      end

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end
  end
end
