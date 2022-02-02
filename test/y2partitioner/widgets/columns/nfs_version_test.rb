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
require_relative "./shared_examples"

require "y2partitioner/widgets/columns/nfs_version"
require "y2storage/filesystems/legacy_nfs"

describe Y2Partitioner::Widgets::Columns::NfsVersion do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "nfs1.xml" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }

  before do
    devicegraph_stub(scenario)
  end

  describe "#value_for" do
    shared_examples "version" do
      let(:options) { ["vers=3"] }

      it "returns the name of its version" do
        expect(subject.value_for(device)).to eq("NFSv3")
      end

      context "and it is using a legacy version format" do
        let(:options) { ["vers=4", "minorversion=1"] }

        it "adds \"(Please Check)\" to the name of its version" do
          expect(subject.value_for(device)).to eq("NFSv4 (Please Check)")
        end
      end
    end

    context "when the given device is a NFS" do
      let(:device) { devicegraph.nfs_mounts.find { |m| m.name == "srv:/home/a" } }

      before do
        device.mount_point.mount_options = options
      end

      include_examples "version"
    end

    context "when the given device is a Legacy NFS" do
      let(:device) { Y2Storage::Filesystems::LegacyNfs.new }

      before do
        device.fstopt = options.join(",")
      end

      include_examples "version"
    end
  end
end
