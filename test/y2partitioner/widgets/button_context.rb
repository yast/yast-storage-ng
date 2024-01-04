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
# find current contact information at www.suse.com

require_relative "../test_helper"

shared_context "action button context" do
  before do
    devicegraph_stub(scenario)

    allow(action).to receive(:new).and_return(instance_double(action, run: action_result))
  end

  subject { described_class.new }

  let(:action_result) { :finish }

  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
end

shared_context "device button context" do
  include_context "action button context"

  subject { described_class.new(device:) }

  before do
    allow(action).to receive(:new).with(device).and_return(instance_double(action, run: action_result))
  end
end
