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
# find current contact information at www.suse.com.

require_relative "../../test_helper"
require_relative "shared_examples"

require "y2partitioner/widgets/columns/nfs_server"
require "y2storage/filesystems/legacy_nfs"

describe Y2Partitioner::Widgets::Columns::NfsServer do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "nfs1.xml" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }

  before do
    devicegraph_stub(scenario)
  end

  describe "#value_for" do
    context "when the given device is a NFS" do
      let(:device) { devicegraph.nfs_mounts.find { |m| m.name == "srv:/home/a" } }

      it "return its server" do
        expect(subject.value_for(device)).to eq("srv")
      end
    end

    context "when the given device is a Legacy NFS" do
      let(:device) { Y2Storage::Filesystems::LegacyNfs.new }

      before do
        device.server = "test"
        device.path = "/test"
      end

      it "return its server" do
        expect(subject.value_for(device)).to eq("test")
      end
    end
  end
end
