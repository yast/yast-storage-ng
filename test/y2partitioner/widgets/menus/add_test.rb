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
require_relative "examples"
require_relative "matchers"

require "y2partitioner/widgets/menus/add"

describe Y2Partitioner::Widgets::Menus::Add do
  before do
    devicegraph_stub(scenario)
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name(device_name) }

  subject { described_class.new(device) }

  let(:scenario) { "one-empty-disk.yml" }

  let(:device_name) { "/dev/sda" }

  include_examples "Y2Partitioner::Widgets::Menus"

  describe "#items" do
    it "includes 'RAID'" do
      expect(subject.items).to include(item_with_id(:menu_add_md))
    end

    it "includes 'LVM Volume Group'" do
      expect(subject.items).to include(item_with_id(:menu_add_vg))
    end

    it "includes 'Btrfs'" do
      expect(subject.items).to include(item_with_id(:menu_add_btrfs))
    end

    it "includes 'Bcache'" do
      expect(subject.items).to include(item_with_id(:menu_add_bcache))
    end

    it "includes 'Partition'" do
      expect(subject.items).to include(item_with_id(:menu_add_partition))
    end

    it "includes 'Logical Volume'" do
      expect(subject.items).to include(item_with_id(:menu_add_lv))
    end
  end

  describe "#disabled_items" do
    context "when the device is a disk device (Hard Disk, BIOS RAID, Multipath, DASD)" do
      let(:scenario) { "one-empty-disk.yml" }

      let(:device_name) { "/dev/sda" }

      it "contains 'Logical Volume'" do
        items = [:menu_add_lv]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a partition" do
      let(:scenario) { "mixed_disks.yml" }

      let(:device_name) { "/dev/sda1" }

      it "contains 'Logical Volume'" do
        items = [:menu_add_lv]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a MD RAID" do
      let(:scenario) { "md_raid.yml" }

      let(:device_name) { "/dev/md/md0" }

      it "contains 'Logical Volume'" do
        items = [:menu_add_lv]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a LVM Volume Group" do
      let(:scenario) { "trivial_lvm.yml" }

      let(:device_name) { "/dev/vg0" }

      it "contains 'Partition'" do
        items = [:menu_add_partition]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a LVM Logical Volume" do
      let(:scenario) { "trivial_lvm.yml" }

      let(:device_name) { "/dev/vg0/lv1" }

      it "contains 'Partition'" do
        items = [:menu_add_partition]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a Bcache" do
      let(:scenario) { "bcache1.xml" }

      let(:device_name) { "/dev/bcache0" }

      it "contains 'Logical Volume'" do
        items = [:menu_add_lv]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end

    context "when the device is a Btrfs" do
      let(:scenario) { "trivial_btrfs.yml" }

      let(:device_name) { "/dev/sda1" }

      subject { described_class.new(device.blk_filesystem) }

      it "contains 'Partition' and 'Logical Volume'" do
        items = [:menu_add_partition, :menu_add_lv]
        expect(subject.disabled_items).to contain_exactly(*items)
      end
    end
  end

  describe "#handle" do
    shared_examples "no action" do |scenario, device_name|
      context "and another type of device is selected" do
        let(:scenario) { scenario }

        let(:device_name) { device_name }

        it "calls none action" do
          expect(Y2Partitioner::Actions::Base).to_not receive(:new)

          subject.handle(event)
        end
      end
    end

    context "when 'RAID' is selected" do
      let(:event) { :menu_add_md }

      it "calls an action to add a MD RAID" do
        expect(Y2Partitioner::Actions::AddMd).to receive(:new)

        subject.handle(event)
      end
    end

    context "when 'LVM Volume Group' is selected" do
      let(:event) { :menu_add_vg }

      it "calls an action to add a Volume Group" do
        expect(Y2Partitioner::Actions::AddLvmVg).to receive(:new)

        subject.handle(event)
      end
    end

    context "when 'Btrfs' is selected" do
      let(:event) { :menu_add_btrfs }

      it "calls an action to add a Btrfs" do
        expect(Y2Partitioner::Actions::AddBtrfs).to receive(:new)

        subject.handle(event)
      end
    end

    context "when 'Bcache' is selected" do
      let(:event) { :menu_add_bcache }

      it "calls an action to add a Bcache" do
        expect(Y2Partitioner::Actions::AddBcache).to receive(:new)

        subject.handle(event)
      end
    end

    context "when 'Partition' is selected" do
      let(:event) { :menu_add_partition }

      context "and the selected device can be partitioned" do
        let(:scenario) { "mixed_disks.yml" }

        let(:device_name) { "/dev/sda" }

        it "calls an action to add a partition in the selected device" do
          expect(Y2Partitioner::Actions::AddPartition).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a partition" do
        let(:scenario) { "mixed_disks.yml" }

        let(:device_name) { "/dev/sda1" }

        it "calls an action to add a partition in the parent of the selected device" do
          expect(Y2Partitioner::Actions::AddPartition).to receive(:new).with(device.partitionable)

          subject.handle(event)
        end
      end

      include_examples "no action", "trivial_lvm.yml", "/dev/vg0"
    end

    context "when 'Logical Volume' is selected" do
      let(:event) { :menu_add_lv }

      context "and the selected device is a LVM Volume Group" do
        let(:scenario) { "trivial_lvm.yml" }

        let(:device_name) { "/dev/vg0" }

        it "calls an action to add a Logical Volume in the selected device" do
          expect(Y2Partitioner::Actions::AddLvmLv).to receive(:new).with(device)

          subject.handle(event)
        end
      end

      context "and the selected device is a LVM Logical Volume" do
        let(:scenario) { "trivial_lvm.yml" }

        let(:device_name) { "/dev/vg0/lv1" }

        it "calls an action to add a Logical Volume in the Volume Group of the selected device" do
          expect(Y2Partitioner::Actions::AddLvmLv).to receive(:new).with(device.lvm_vg)

          subject.handle(event)
        end
      end

      include_examples "no action", "mixed_disks.yml", "/dev/sda1"
    end
  end
end
