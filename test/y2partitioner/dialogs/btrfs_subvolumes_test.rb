#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
require "y2partitioner/dialogs/btrfs_subvolumes"

describe Y2Partitioner::Dialogs::BtrfsSubvolumes do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:partition) { Y2Storage::Partition.find_by_name(current_graph, "/dev/sda2") }

  let(:filesystem) { partition.filesystem }

  subject { described_class.new(filesystem) }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "has a btrfs subvolumes widget" do
      expect(Y2Partitioner::Widgets::BtrfsSubvolumes).to receive(:new)
      subject.contents
    end
  end

  describe "#run" do
    before do
      allow_any_instance_of(Y2Partitioner::Dialogs::Popup).to receive(:run).and_return(result)
    end

    context "when the result is accepted" do
      let(:result) { :ok }

      it "stores the new devicegraph with all its changes" do
        previous_graph = Y2Partitioner::DeviceGraphs.instance.current
        subject.run
        current_graph = Y2Partitioner::DeviceGraphs.instance.current

        expect(current_graph.object_id).to_not eq(previous_graph.object_id)
      end
    end

    context "when the result is not accepted" do
      let(:result) { :cancel }

      it "keeps the initial devicegraph" do
        previous_graph = Y2Partitioner::DeviceGraphs.instance.current
        subject.run
        current_graph = Y2Partitioner::DeviceGraphs.instance.current

        expect(current_graph.object_id).to eq(previous_graph.object_id)
        expect(current_graph).to eq(previous_graph)
      end
    end
  end
end
