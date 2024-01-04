#!/usr/bin/env rspec
# Copyright (c) [2019-2021] SUSE LLC
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
require "y2partitioner/widgets/btrfs_filesystems_table"

describe Y2Partitioner::Widgets::BtrfsFilesystemsTable do
  before do
    devicegraph_stub("mixed_disks_btrfs")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(entries, pager) }

  let(:filesystems) { device_graph.btrfs_filesystems }
  let(:entries) { filesystems.map { |fs| Y2Partitioner::Widgets::DeviceTableEntry.new(fs) } }

  let(:pager) { double("Pager") }

  # FIXME: default tests check that all column headers are strings, but they also can be a Yast::Term
  # include_examples "CWM::Table"

  describe "#header" do
    it "returns an array including the quota and the subvolume sizes" do
      expect(subject.header).to be_a(Array)
      titles = subject.header.map { |col| col.is_a?(Yast::Term) ? col.params.first : col }
      expect(titles).to include("Ref. Size", "Excl. Size", "Size Limit")
    end
  end

  describe "#items" do
    it "returns array of CWM table items" do
      expect(subject.items).to be_a(Array)
      expect(subject.items.first).to be_a(CWM::TableItem)
    end
  end

  describe "#open_items" do
    context "when #open_items has not been set" do
      before { subject.open_items = nil }

      let(:sids_with_snapshots) { filesystems.select(&:snapshots?).map(&:sid) }
      let(:sids_without_snapshots) { filesystems.reject(&:snapshots?).map(&:sid) }

      it "reports true for items with only regular subvolumes as children" do
        result = subject.open_items
        sids_without_snapshots.each do |sid|
          expect(result["table:device:#{sid}"]).to eq true
        end
      end

      it "reports true for items with some btrfs snapshot as child" do
        result = subject.open_items
        sids_with_snapshots.each do |sid|
          expect(result["table:device:#{sid}"]).to eq true
        end
      end
    end
  end
end
