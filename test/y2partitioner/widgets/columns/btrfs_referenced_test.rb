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
require_relative "shared_examples"

require "y2partitioner/widgets/columns/btrfs_referenced"

describe Y2Partitioner::Widgets::Columns::BtrfsReferenced do
  using Y2Storage::Refinements::SizeCasts

  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "btrfs_simple_quotas.xml" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, device_name) }
  let(:device) { blk_device }

  let(:device_name) { "/dev/vda2" }

  before do
    devicegraph_stub(scenario)
  end

  describe "#value_for" do
    context "when no device is given" do
      let(:device_name) { "unknonw" }

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when the device is a partition" do
      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when the device is a btrfs filesystem" do
      let(:device) { blk_device.filesystem }

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when the device is a btrfs subvolume" do
      let(:device) { blk_device.filesystem.find_btrfs_subvolume_by_path("@/home") }

      context "and quotas are not enabled" do
        before do
          blk_device.filesystem.quota = false
        end

        it "returns empty string" do
          expect(subject.value_for(device)).to eq("")
        end
      end

      context "and quotas are active" do
        it "contains the human readable representation of the referenced size" do
          value = subject.value_for(device)
          size = value.params[0]

          expect(size).to eq("48.00 KiB")
        end

        it "contains a sort key for the device referenced size" do
          value = subject.value_for(device)
          sort_key = value.params.find { |param| param.is_a?(Yast::Term) && param.value == :sortKey }

          expect(sort_key).to_not be_nil
          expect(sort_key.params).to include("49152")
        end
      end
    end
  end
end
