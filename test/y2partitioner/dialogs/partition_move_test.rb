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

require "yast"
require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/partition_move"

# Yast.import "UI"

describe Y2Partitioner::Dialogs::PartitionMove do
  before do
    devicegraph_stub("mixed_disks")
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(partition, possible_movement) }

  let(:partition) { current_graph.find_by_name("/dev/sda1") }

  let(:possible_movement) { :both }

  include_examples "CWM::Dialog"

  describe "#contents" do
    context "when the partition can be moved towards the beginning and the end" do
      let(:possible_movement) { :both }

      it "contains a widget for selecting the movement direction" do
        widget = subject.contents.nested_find do |i|
          i.is_a?(Y2Partitioner::Dialogs::PartitionMove::DirectionSelector)
        end
        expect(widget).to_not be_nil
      end
    end

    context "when the partition can be moved towards the beginning" do
      let(:possible_movement) { :beginning }

      it "contains a label for asking whether to move towards the beginning" do
        widget = subject.contents.nested_find do |i|
          i.is_a?(Yast::Term) && i.value == :Label &&
            i.params.first.match?(/towards the beginning\?/)
        end

        expect(widget).to_not be_nil
      end
    end

    context "when the partition can be moved towards the end" do
      let(:possible_movement) { :end }

      it "contains a label for asking whether to move towards the end" do
        widget = subject.contents.nested_find do |i|
          i.is_a?(Yast::Term) && i.value == :Label &&
            i.params.first.match?(/towards the end\?/)
        end

        expect(widget).to_not be_nil
      end
    end
  end

  describe Y2Partitioner::Dialogs::PartitionMove::DirectionSelector do
    subject { described_class.new(dialog) }

    let(:dialog) { Y2Partitioner::Dialogs::PartitionMove.new(partition, possible_movement) }

    include_examples "CWM::RadioButtons"
  end
end
