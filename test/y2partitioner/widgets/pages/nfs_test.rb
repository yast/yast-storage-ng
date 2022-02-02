#!/usr/bin/env rspec

# Copyright (c) [2022] SUSE LLC
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
require "y2partitioner/widgets/pages/nfs"

describe Y2Partitioner::Widgets::Pages::Nfs do
  before do
    devicegraph_stub("nfs1.xml")
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:nfs) { current_graph.nfs_mounts.first }

  subject { described_class.new(nfs, pager) }

  let(:pager) { double("OverviewTreePager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a table with the current NFS" do
      table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::NfsMountsTable) }
      expect(table).to_not be_nil

      first_column = column_values(table, 0)
      expect(first_column).to contain_exactly(nfs.server)
    end

    it "shows a buttons set" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceButtonsSet) }
      expect(button).to_not be_nil
    end

    it "does not show a button to add a new Nfs filesystem" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::NfsAddButton) }
      expect(button).to be_nil
    end
  end
end
