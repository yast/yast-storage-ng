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

require "y2partitioner/widgets/columns/stripes"

describe Y2Partitioner::Widgets::Columns::Stripes do
  using Y2Storage::Refinements::SizeCasts
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  describe "#value_for" do
    let(:scenario) { "lvm-types1.xml" }
    let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
    let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, device_name) }

    before do
      devicegraph_stub(scenario)
    end

    context "when the device responds to #stripes" do
      let(:device_name) { "/dev/vg0/striped1" }

      it "includes the stripes number" do
        expect(subject.value_for(device)).to include("2")
      end

      it "includes the human readable stripes size" do
        expect(subject.value_for(device)).to include("4.00 KiB")
      end
    end

    context "when the device does not respond to #stripes" do
      let(:device_name) { "/dev/sda" }

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end
  end
end
