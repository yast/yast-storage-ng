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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "y2partitioner/widgets/device_table_entry"

describe Y2Partitioner::Widgets::DeviceTableEntry do
  before do
    devicegraph_stub(scenario)
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name(device_name) }

  describe ".new_with_children" do
    let(:entry) { described_class.new_with_children(device) }

    shared_examples "create entry" do
      it "creates an entry for the given device" do
        expect(entry).is_a?(described_class)
        expect(entry.device).to eq(device)
      end
    end

    shared_examples "create subvolumes entries" do
      it "creates children entries for its Btrfs subvolumes" do
        expect(entry.children).to all(be_a(described_class))

        children_devices = entry.children.map(&:device)

        expect(children_devices.map(&:path)).to contain_exactly("@/home", "@/srv", "@/tmp")
      end
    end

    context "when the given device is a LVM volume group" do
      let(:scenario) { "lvm-two-vgs" }

      let(:device_name) { "/dev/vg0" }

      include_examples "create entry"

      it "creates children entries for its LVM logical volumes" do
        expect(entry.children).to all(be_a(described_class))

        children_devices = entry.children.map(&:device)

        expect(children_devices.map(&:name)).to contain_exactly("/dev/vg0/lv1", "/dev/vg0/lv2")
      end
    end

    context "when the given device is formatted as Btrfs" do
      let(:scenario) { "mixed_disks_btrfs" }

      let(:device_name) { "/dev/sda2" }

      include_examples "create entry"

      context "and the Btrfs is not multidevice" do
        let(:device_name) { "/dev/sdb2" }

        include_examples "create subvolumes entries"

        it "does not create a child entry for the prefix subvolume" do
          device.filesystem.subvolumes_prefix = "@/home"

          children_devices = entry.children.map(&:device)

          expect(children_devices.map(&:path)).to_not include("@/home")
        end
      end

      context "and the Btrfs is multidevice" do
        let(:scenario) { "btrfs-multidevice-over-partitions.xml" }

        let(:device_name) { "/dev/sda2" }

        it "does not create children entries" do
          expect(entry.children).to be_empty
        end
      end
    end

    context "when the given device is a Btrfs filesystem" do
      let(:scenario) { "mixed_disks_btrfs" }

      let(:device) { current_graph.find_by_name("/dev/sdb2").filesystem }

      include_examples "create entry"

      include_examples "create subvolumes entries"

      it "does not create a child entry for the prefix subvolume" do
        device.subvolumes_prefix = "@/home"

        children_devices = entry.children.map(&:device)

        expect(children_devices.map(&:path)).to_not include("@/home")
      end
    end

    context "when the given device contains partitions" do
      let(:scenario) { "mixed_disks_btrfs" }

      let(:device_name) { "/dev/sdb" }

      include_examples "create entry"

      it "creates children entries only for its primary and extended partitions" do
        expect(entry.children).to all(be_a(described_class))

        children_devices = entry.children.map(&:device)

        expect(children_devices.map(&:basename)).to contain_exactly("sdb1", "sdb2", "sdb3", "sdb4")
      end
    end

    context "when the given device is an extended partition" do
      let(:scenario) { "mixed_disks_btrfs" }

      let(:device_name) { "/dev/sdb4" }

      include_examples "create entry"

      it "creates children entries for its logical partitions" do
        expect(entry.children).to all(be_a(described_class))

        children_devices = entry.children.map(&:device)

        expect(children_devices.map(&:basename)).to contain_exactly("sdb5", "sdb6", "sdb7")
      end
    end

    context "when another device is given" do
      let(:scenario) { "mixed_disks_btrfs" }

      # /dev/sdb5 is a logical partition
      let(:device_name) { "/dev/sdb5" }

      include_examples "create entry"

      it "does not create children entries" do
        expect(entry.children).to be_empty
      end
    end
  end

  describe "#parent?" do
    let(:scenario) { "mixed_disks_btrfs" }

    let(:device_name) { "/dev/sdb" }

    subject { described_class.new_with_children(device) }

    context "when the given entry is a direct children" do
      let(:entry) { subject.children.first }

      it "returns true" do
        expect(subject.parent?(entry)).to eq(true)
      end
    end

    context "when the given entry is not a direct children" do
      let(:sdb2_entry) { subject.children.find { |c| c.device.name = "/dev/sdb2" } }

      let(:entry) { sdb2_entry.children.first }

      it "returns false" do
        expect(subject.parent?(entry)).to eq(false)
      end
    end
  end
end
