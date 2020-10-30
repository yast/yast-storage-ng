#!/usr/bin/env rspec
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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/visual_device_graph"
require "y2partitioner/widgets/overview"

describe Y2Partitioner::Widgets::VisualDeviceGraph do
  before do
    devicegraph_stub("complex-lvm-encrypt")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject(:widget) { described_class.new(device_graph) }

  include_examples "CWM::CustomWidget"

  describe "#init" do
    it "updates the content of the graph widget" do
      allow(Yast::Term).to receive(:new)
      expect(Yast::Term).to receive(:new).with(:Graph, any_args)
      expect(Yast::UI).to receive(:ReplaceWidget)
      widget.init
    end
  end
end
