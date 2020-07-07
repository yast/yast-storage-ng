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

require_relative "../../test_helper"
require_relative "./shared_examples"

require "y2partitioner/widgets/columns/device"

describe Y2Partitioner::Widgets::Columns::Device do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "mixed_disks" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }

  before do
    devicegraph_stub(scenario)
  end

  describe "#value_for" do
    let(:value) { subject.value_for(device) }
    let(:name) { remove_sort_key(value) }
    let(:sort_key) do
      sk = value.params.find { |p| p.is_a?(Yast::Term) && p.value == :sortKey }
      sk.params[0] unless sk.nil?
    end

    context "when the device is not a filesystem" do
      let(:dev_name) { "/dev/sdb1" }
      let(:device) { blk_device }

      it "returns the device display name" do
        expect(name).to eq(device.display_name)
      end

      it "uses the sort key provided by libstorage-ng" do
        expect(sort_key).to eq(device.name_sort_key)
      end
    end

    context "when the device is a single-device filesystem" do
      let(:dev_name) { "/dev/sda2" }
      let(:device) { blk_device.filesystem }

      it "returns its readable filesystem type name" do
        expect(name).to eq("Ext4")
      end

      it "does not provide a sort key" do
        expect(sort_key).to be_nil
      end
    end

    context "when the device is a multi-device filesystem" do
      let(:scenario) { "btrfs2-devicegraph.xml" }
      let(:dev_name) { "/dev/sdb1" }
      let(:device) { blk_device.filesystem }

      it "includes the human readable filesystem type" do
        expect(name).to include("BtrFS")
      end

      it "includes the #blk_device_basename" do
        expect(name).to include("sdb1")
      end

      it "does not provide a sort key" do
        expect(sort_key).to be_nil
      end
    end
  end
end
