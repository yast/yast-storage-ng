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
# find current contact information at www.suse.com

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::Base do
  let(:scenario) { "empty_disks.yml" }
  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:disks) { current_graph.disks }
  let(:disk) { disks.first }

  before do
    devicegraph_stub(scenario)
  end

  describe "#id" do
    let(:pager) { double("Pager") }

    context "when it's a device page" do
      let(:page) { Y2Partitioner::Widgets::Pages::Disk.new(disk, pager) }

      it "returns the device sid" do
        expect(page.id).to eq(disk.sid)
      end
    end

    context "when it isn't a device page" do
      let(:page) { Y2Partitioner::Widgets::Pages::Disks.new(disks, pager) }

      it "returns the page label" do
        expect(page.id).to eq(page.label)
      end
    end
  end
end
