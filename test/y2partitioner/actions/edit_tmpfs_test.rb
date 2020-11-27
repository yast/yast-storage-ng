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
require "y2partitioner/device_graphs"
require "y2partitioner/actions/edit_tmpfs"

describe Y2Partitioner::Actions::EditTmpfs do
  before do
    devicegraph_stub("tmpfs1-devicegraph.xml")
  end

  subject { described_class.new(filesystem) }
  let(:filesystem) { Y2Partitioner::DeviceGraphs.instance.current.tmp_filesystems.first }

  describe "#run" do
    context "if the user goes forward in the dialog" do
      before do
        allow(Y2Partitioner::Dialogs::Tmpfs).to receive(:run).and_return(:next)
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end
    end

    context "if the user aborts the process" do
      before do
        allow(Y2Partitioner::Dialogs::Tmpfs).to receive(:run).and_return(:abort)
      end

      it "returns :abort" do
        expect(subject.run).to eq(:abort)
      end
    end
  end
end
