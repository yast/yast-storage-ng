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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/btrfs_quota"
require "y2partitioner/actions/controllers"

describe Y2Partitioner::Widgets::BtrfsQuota do
  before { devicegraph_stub(scenario) }

  let(:scenario) { "btrfs_simple_quotas.xml" }
  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:blk_device) { current_graph.find_by_name("/dev/vda2") }

  let(:controller) do
    Y2Partitioner::Actions::Controllers::Filesystem.new(blk_device, "")
  end

  subject { described_class.new(controller) }

  include_examples "CWM::AbstractWidget"
end
