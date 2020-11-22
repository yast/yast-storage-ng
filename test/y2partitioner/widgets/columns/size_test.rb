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

require "y2partitioner/widgets/columns/size"

describe Y2Partitioner::Widgets::Columns::Size do
  using Y2Storage::Refinements::SizeCasts

  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "mixed_disks" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, device_name) }
  let(:device_name) { "/dev/sda1" }

  before do
    devicegraph_stub(scenario)
  end

  shared_examples "value for size" do
    let(:disk_size) { Y2Storage::DiskSize.new(60.GiB) }

    before do
      allow(device).to receive(:size).and_return(disk_size)
    end

    it "returns a Yast::Term" do
      expect(subject.value_for(device)).to be_a(Yast::Term)
    end

    it "contains the human readable representation of the device size" do
      value = subject.value_for(device)
      size = value.params[0]

      expect(size).to eq("60.00 GiB")
    end

    it "contains a sort key for the device size" do
      value = subject.value_for(device)
      sort_key = value.params.find { |param| param.is_a?(Yast::Term) && param.value == :sortKey }

      expect(sort_key).to_not be_nil
      expect(sort_key.params).to include("64424509440")
    end
  end

  describe "#value_for" do
    context "when no device is given" do
      let(:device_name) { "unknonw" }

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when the device responds to #size method" do
      include_examples "value for size"
    end

    context "when the device does not respond to #size method" do
      before do
        allow(device).to receive(:respond_to?).with(:size).and_return(false)
      end

      it "returns empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when a fstab entry is given" do
      let(:btrfs) { Y2Storage::Filesystems::Type::BTRFS }
      let(:root_fstab_entry) { fstab_entry("/dev/sdb2", "/", btrfs, ["subvol=@/"], 0, 0) }
      let(:unknown_fstab_entry) { fstab_entry("/dev/vdz", "/home", btrfs, [], 0, 0) }

      context "and the device is found in the system" do
        let(:device) { root_fstab_entry }

        include_examples "value for size"
      end

      context "but the device is not found in the system" do
        let(:device) { unknown_fstab_entry }

        it "returns an empty string" do
          expect(subject.value_for(device)).to eq("")
        end
      end
    end

    context "when the device is a btrfs subvolume" do
      let(:scenario) { "btrfs_simple_quotas.xml" }
      let(:device_name) { "/dev/vda2" }
      let(:subvolume) { device.filesystem.find_btrfs_subvolume_by_path("@/opt") }

      before { subvolume.referenced_limit = limit }

      context "if the subvolume has no quota" do
        let(:limit) { Y2Storage::DiskSize.unlimited }

        it "returns empty string" do
          expect(subject.value_for(subvolume)).to eq("")
        end
      end

      context "if the subvolume has a quota" do
        let(:limit) { 512.MiB }

        it "contains the human readable representation of the device size" do
          value = subject.value_for(subvolume)
          size = value.params[0]

          expect(size).to eq("0.50 GiB")
        end

        it "contains a sort key for the device size" do
          value = subject.value_for(subvolume)
          sort_key = value.params.find { |param| param.is_a?(Yast::Term) && param.value == :sortKey }

          expect(sort_key).to_not be_nil
          expect(sort_key.params).to include("536870912")
        end
      end
    end
  end
end
