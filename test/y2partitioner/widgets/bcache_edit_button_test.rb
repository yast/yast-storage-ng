#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/widgets/bcache_edit_button"

describe Y2Partitioner::Widgets::BcacheEditButton do
  before do
    devicegraph_stub(scenario)

    allow(Y2Partitioner::Actions::EditBcache).to receive(:new).and_return(action)
  end

  # Bcache is only supported on x86
  let(:architecture) { :x86_64 }

  let(:action) { instance_double(Y2Partitioner::Actions::EditBcache, run: :finish) }

  subject(:button) { described_class.new(device: device) }

  let(:device) { device_graph.find_by_name(device_name) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "bcache1.xml" }

  let(:device_name) { "/dev/bcache0" }

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
