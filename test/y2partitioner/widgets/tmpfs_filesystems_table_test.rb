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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/device_table_entry"
require "y2partitioner/widgets/tmpfs_filesystems_table"

describe Y2Partitioner::Widgets::TmpfsFilesystemsTable do
  before do
    devicegraph_stub("tmpfs1-devicegraph.xml")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(entries, pager) }

  let(:filesystems) { device_graph.tmp_filesystems }

  let(:entries) { filesystems.map { |f| Y2Partitioner::Widgets::DeviceTableEntry.new(f) } }

  let(:pager) { double("Pager") }

  # FIXME: default tests check that all column headers are strings, but they also can be a Yast::Term
  # include_examples "CWM::Table"

  describe "#items" do
    it "returns array of CWM table items" do
      expect(subject.items).to be_a(Array)
      expect(subject.items).to all(be_a(CWM::TableItem))
    end

    it "returns an item per each given entry" do
      expect(subject.items.map(&:id)).to contain_exactly(*entries.map(&:row_id))
    end
  end
end
