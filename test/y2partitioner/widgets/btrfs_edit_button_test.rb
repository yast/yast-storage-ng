#!/usr/bin/env rspec
# Copyright (c) [2017-2019] SUSE LLC
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
require "y2partitioner/widgets/btrfs_edit_button"

describe Y2Partitioner::Widgets::BtrfsEditButton do
  before do
    devicegraph_stub(scenario)

    allow(Y2Partitioner::Actions::EditBtrfs).to receive(:new).and_return(action)
  end

  let(:action) { instance_double(Y2Partitioner::Actions::EditBtrfs, run: :finish) }

  subject(:button) { described_class.new(device: filesystem) }

  let(:device) { device_graph.find_by_name(device_name) }

  let(:filesystem) { device.filesystem }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks" }

  let(:device_name) { "/dev/sdb2" }

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "returns :redraw if the action was successful" do
      allow(action).to receive(:run).and_return(:finish)

      expect(button.handle).to eq(:redraw)
    end

    it "returns nil if the action was not successful" do
      allow(action).to receive(:run).and_return(:back)

      expect(button.handle).to be_nil
    end
  end
end
