#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/widgets/btrfs_add_button"

describe Y2Partitioner::Widgets::BtrfsAddButton do
  subject(:button) { described_class.new }

  let(:sequence) { double("AddBtrfs") }

  before do
    devicegraph_stub("one-empty-disk.yml")
    allow(Y2Partitioner::Actions::AddBtrfs).to receive(:new).and_return sequence
    allow(sequence).to receive(:run)
  end

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "starts an AddBtrfs sequence" do
      expect(sequence).to receive(:run)
      button.handle
    end

    it "returns :redraw if the sequence returns :finish" do
      allow(sequence).to receive(:run).and_return :finish
      expect(button.handle).to eq :redraw
    end

    it "returns nil if the sequence does not return :finish" do
      allow(sequence).to receive(:run).and_return :back
      expect(button.handle).to be_nil
    end
  end
end
