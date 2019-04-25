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
# find current contact information at www.suse.com.

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/filesystem_description"

describe Y2Partitioner::Widgets::FilesystemDescription do
  before do
    devicegraph_stub("mixed_disks")
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name("/dev/sda2") }

  let(:filesystem) { device.filesystem }

  subject { described_class.new(filesystem) }

  include_examples "CWM::RichText"

  describe "#init" do
    it "includes a filesystem section" do
      expect(Y2Partitioner::Widgets::DescriptionSection::Filesystem).to receive(:new)
        .and_call_original

      subject.init
    end
  end
end
