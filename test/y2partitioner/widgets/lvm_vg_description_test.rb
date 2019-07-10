#!/usr/bin/env rspec
# encoding: utf-8

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
# find current contact information at www.suse.com.

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/lvm_vg_description"

describe Y2Partitioner::Widgets::LvmVgDescription do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:lvm_vg) { current_graph.lvm_vgs.first }

  subject { described_class.new(lvm_vg) }

  include_examples "CWM::RichText"

  describe "#init" do
    it "runs without failure" do
      expect { subject.init }.to_not raise_error
    end
  end
end
