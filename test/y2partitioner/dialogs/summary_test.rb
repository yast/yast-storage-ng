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
require "y2partitioner/dialogs/summary"

describe Y2Partitioner::Dialogs::Summary do
  before { devicegraph_stub("one-empty-disk.yml") }

  subject { described_class.new }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "contains a widget with the summary of actions to perform" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Widgets::SummaryText)
      end

      expect(widget).to_not be_nil
    end
  end

  describe "#abort_handler" do
    before do
      devicegraphs = Y2Partitioner::DeviceGraphs.instance
      allow(devicegraphs).to receive(:devices_edited?).and_return(true)

      allow(Y2Partitioner::DeviceGraphs).to receive(:instance).and_return(devicegraphs)

      allow(Yast2::Popup).to receive(:show).and_return(accept)
    end

    let(:accept) { nil }

    it "shows a confirmation popup" do
      expect(Yast2::Popup).to receive(:show)

      subject.abort_handler
    end

    context "and the user accepts" do
      let(:accept) { :yes }

      it "aborts (returns true)" do
        expect(subject.abort_handler).to eq(true)
      end
    end

    context "and the user does not accept" do
      let(:accept) { :no }

      it "does not abort (returns false)" do
        expect(subject.abort_handler).to eq(false)
      end
    end
  end
end
