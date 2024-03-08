#!/usr/bin/env rspec

# Copyright (c) [2020-2024] SUSE LLC
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

require "y2partitioner/widgets/columns/type"

describe Y2Partitioner::Widgets::Columns::Type do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  describe "#value_for" do
    let(:scenario) { "md_raid.yml" }
    let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
    let(:device) { devicegraph.find_by_name("/dev/sda2") }
    let(:label) { subject.value_for(device).params.find { |param| !param.is_a?(Yast::Term) } }

    before do
      devicegraph_stub(scenario)
    end

    it "returns a Yast::Term" do
      expect(subject.value_for(device)).to be_a(Yast::Term)
    end

    it "includes an icon" do
      value = subject.value_for(device)
      icon = value.params.find { |param| param.is_a?(Yast::Term) && param.value == :icon }

      expect(icon).to_not be_nil
    end

    it "includes the description of the device" do
      expect(label).to include("Part of md0")
    end
  end
end
